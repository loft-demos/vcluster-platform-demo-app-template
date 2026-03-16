#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Build and push the demo app image to a Forgejo container registry.

Default behavior:
- builds ./src/Dockerfile for the local native Linux platform
- logs into the target registry
- pushes two tags:
  - the local git short SHA
  - the Helm chart appVersion

Usage:
  bash scripts/build-push-forgejo-image.sh \
    --registry forgejo.vcp.local \
    --image-repository-prefix forgejo.vcp.local/vcluster-demos/vcp-gitops \
    --repo-name vcp-gitops \
    --username demo-admin \
    --password "$FORGEJO_ADMIN_PASSWORD"

Options:
  --registry HOST                 Registry host, for example forgejo.vcp.local
  --image-repository-prefix PATH  Registry path prefix, for example forgejo.vcp.local/vcluster-demos/vcp-gitops
  --repo-name NAME                Repo name used to derive the image name. Default: current repo name
  --image-name NAME               Final image name. Default: <repo-name>-demo-app
  --username NAME                 Registry username
  --token VALUE                   Registry token. Defaults to FORGEJO_TOKEN
  --password VALUE                Registry password. Defaults to FORGEJO_PASSWORD
  --context PATH                  Docker build context. Default: src
  --dockerfile PATH               Dockerfile path. Default: src/Dockerfile
  --chart-file PATH               Helm chart file used to read appVersion. Default: helm-chart/Chart.yaml
  --platform VALUE                Docker platform. Default: auto-detect from the local machine
  --source-url URL                OCI source label URL
  --skip-cache                    Disable registry build cache
  --help                          Show this message
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd" >&2
    exit 1
  fi
}

REGISTRY=""
IMAGE_REPOSITORY_PREFIX=""
REPO_NAME=""
IMAGE_NAME=""
USERNAME=""
TOKEN="${FORGEJO_TOKEN:-}"
PASSWORD="${FORGEJO_PASSWORD:-}"
CONTEXT_PATH="src"
DOCKERFILE_PATH="src/Dockerfile"
CHART_FILE="helm-chart/Chart.yaml"
PLATFORM="auto"
SOURCE_URL=""
SKIP_CACHE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry)
      REGISTRY="${2:-}"
      shift 2
      ;;
    --image-repository-prefix)
      IMAGE_REPOSITORY_PREFIX="${2:-}"
      shift 2
      ;;
    --repo-name)
      REPO_NAME="${2:-}"
      shift 2
      ;;
    --image-name)
      IMAGE_NAME="${2:-}"
      shift 2
      ;;
    --username)
      USERNAME="${2:-}"
      shift 2
      ;;
    --token)
      TOKEN="${2:-}"
      shift 2
      ;;
    --password)
      PASSWORD="${2:-}"
      shift 2
      ;;
    --context)
      CONTEXT_PATH="${2:-}"
      shift 2
      ;;
    --dockerfile)
      DOCKERFILE_PATH="${2:-}"
      shift 2
      ;;
    --chart-file)
      CHART_FILE="${2:-}"
      shift 2
      ;;
    --platform)
      PLATFORM="${2:-}"
      shift 2
      ;;
    --source-url)
      SOURCE_URL="${2:-}"
      shift 2
      ;;
    --skip-cache)
      SKIP_CACHE="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd docker
require_cmd git
require_cmd sed
require_cmd uname

if [[ -z "$REPO_NAME" ]]; then
  REPO_NAME="$(basename "$(git rev-parse --show-toplevel)")"
fi

if [[ -z "$REGISTRY" ]]; then
  echo "[ERROR] --registry is required." >&2
  exit 1
fi

if [[ -z "$IMAGE_REPOSITORY_PREFIX" ]]; then
  echo "[ERROR] --image-repository-prefix is required." >&2
  exit 1
fi

if [[ -z "$USERNAME" ]]; then
  echo "[ERROR] --username is required." >&2
  exit 1
fi

if [[ -z "$TOKEN" && -z "$PASSWORD" ]]; then
  echo "[ERROR] Provide --token or --password." >&2
  exit 1
fi

if [[ -z "$IMAGE_NAME" ]]; then
  IMAGE_NAME="${REPO_NAME}-demo-app"
fi

if [[ -z "$SOURCE_URL" ]]; then
  SOURCE_URL="https://${REGISTRY}"
fi

if [[ -z "$PLATFORM" || "$PLATFORM" == "auto" ]]; then
  case "$(uname -m)" in
    arm64|aarch64)
      PLATFORM="linux/arm64"
      ;;
    x86_64|amd64)
      PLATFORM="linux/amd64"
      ;;
    *)
      echo "[ERROR] Could not infer a supported image platform from $(uname -m)." >&2
      echo "[ERROR] Use --platform to set it explicitly." >&2
      exit 1
      ;;
  esac
fi

short_sha="$(git rev-parse --short=8 HEAD)"
full_sha="$(git rev-parse HEAD)"
chart_app_version="$(
  sed -n 's/^appVersion:[[:space:]]*//p' "$CHART_FILE" | head -n 1 | tr -d "\"'[:space:]"
)"

if [[ -z "$chart_app_version" ]]; then
  echo "[ERROR] Could not read appVersion from $CHART_FILE." >&2
  exit 1
fi

image_ref="${IMAGE_REPOSITORY_PREFIX%/}/${IMAGE_NAME}"

echo "[INFO] Logging into ${REGISTRY}"
if [[ -n "$TOKEN" ]]; then
  printf '%s' "$TOKEN" | docker login "$REGISTRY" --username "$USERNAME" --password-stdin >/dev/null
else
  printf '%s' "$PASSWORD" | docker login "$REGISTRY" --username "$USERNAME" --password-stdin >/dev/null
fi

if ! docker buildx inspect >/dev/null 2>&1; then
  docker buildx create --use >/dev/null
fi

build_args=(
  build
  --platform "$PLATFORM"
  --file "$DOCKERFILE_PATH"
  --push
  --label "org.opencontainers.image.revision=${full_sha}"
  --label "org.opencontainers.image.title=${IMAGE_NAME}"
  --label "org.opencontainers.image.vendor=loft.sh"
  --label "org.opencontainers.image.source=${SOURCE_URL%/}"
  --tag "${image_ref}:${short_sha}"
  --tag "${image_ref}:${chart_app_version}"
)

if [[ "$SKIP_CACHE" != "true" ]]; then
  build_args+=(
    --cache-from "type=registry,ref=${image_ref}:buildcache"
    --cache-to "type=registry,ref=${image_ref}:buildcache,mode=max"
  )
fi

build_args+=("$CONTEXT_PATH")

echo "[INFO] Building and pushing ${image_ref}"
echo "[INFO] Platform: ${PLATFORM}"
echo "[INFO] Tags: ${short_sha}, ${chart_app_version}"
docker buildx "${build_args[@]}"

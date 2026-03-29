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
  --extra-tag VALUE               Additional image tag to publish. Repeatable.
  --username NAME                 Registry username
  --token VALUE                   Registry token. Defaults to FORGEJO_TOKEN
  --password VALUE                Registry password. Defaults to FORGEJO_PASSWORD
  --context PATH                  Docker build context. Default: src
  --dockerfile PATH               Dockerfile path. Default: src/Dockerfile
  --chart-file PATH               Helm chart file used to read appVersion. Default: helm-chart/Chart.yaml
  --platform VALUE                Docker platform. Default: auto-detect from the local machine
  --source-url URL                OCI source label URL
  --registry-insecure             Allow pushing to an insecure HTTP registry
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
EXTRA_TAGS=()
USERNAME=""
TOKEN="${FORGEJO_TOKEN:-}"
PASSWORD="${FORGEJO_PASSWORD:-}"
CONTEXT_PATH="src"
DOCKERFILE_PATH="src/Dockerfile"
CHART_FILE="helm-chart/Chart.yaml"
PLATFORM="auto"
SOURCE_URL=""
REGISTRY_INSECURE="false"
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
    --extra-tag)
      EXTRA_TAGS+=("${2:-}")
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
    --registry-insecure)
      REGISTRY_INSECURE="true"
      shift
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

echo "[INFO] Configuring registry auth for ${REGISTRY}"
mkdir -p "${HOME}/.docker"
if [[ -n "$PASSWORD" ]]; then
  auth_secret="$PASSWORD"
else
  auth_secret="$TOKEN"
fi
registry_auth="$(printf '%s:%s' "$USERNAME" "$auth_secret" | base64 | tr -d '\n')"
cat >"${HOME}/.docker/config.json" <<EOF
{
  "auths": {
    "${REGISTRY}": {
      "auth": "${registry_auth}"
    }
  }
}
EOF

build_args=(
  build
  --platform "$PLATFORM"
  --file "$DOCKERFILE_PATH"
  --build-arg "IMAGE_TAG=${chart_app_version}"
  --output "type=image,push=true,registry.insecure=${REGISTRY_INSECURE}"
  --label "org.opencontainers.image.revision=${full_sha}"
  --label "org.opencontainers.image.title=${IMAGE_NAME}"
  --label "org.opencontainers.image.vendor=loft.sh"
  --label "org.opencontainers.image.source=${SOURCE_URL%/}"
  --tag "${image_ref}:${short_sha}"
  --tag "${image_ref}:${chart_app_version}"
)

declare -a extra_tags_copy=()
set +u
extra_tags_copy=("${EXTRA_TAGS[@]}")
for extra_tag in "${extra_tags_copy[@]}"; do
  build_args+=(
    --tag "${image_ref}:${extra_tag}"
  )
done
set -u

if [[ "$SKIP_CACHE" != "true" ]]; then
  build_args+=(
    --cache-from "type=registry,ref=${image_ref}:buildcache"
    --cache-to "type=registry,ref=${image_ref}:buildcache,mode=max,ignore-error=true"
  )
fi

build_args+=("$CONTEXT_PATH")

echo "[INFO] Building and pushing ${image_ref}"
echo "[INFO] Platform: ${PLATFORM}"
echo "[INFO] Tags: ${short_sha}, ${chart_app_version}"

if docker buildx version >/dev/null 2>&1; then
  if ! docker buildx inspect >/dev/null 2>&1; then
    docker buildx create --use >/dev/null
  fi
  docker buildx "${build_args[@]}"
else
  echo "[WARN] docker buildx is unavailable; falling back to plain docker build/push without registry cache." >&2

  if [[ "$SKIP_CACHE" != "true" ]]; then
    docker pull "${image_ref}:latest" >/dev/null 2>&1 || true
  fi

  docker_build_args=(
    build
    --platform "$PLATFORM"
    --file "$DOCKERFILE_PATH"
    --build-arg BUILDKIT_INLINE_CACHE=1
    --build-arg "IMAGE_TAG=${chart_app_version}"
    --label "org.opencontainers.image.revision=${full_sha}"
    --label "org.opencontainers.image.title=${IMAGE_NAME}"
    --label "org.opencontainers.image.vendor=loft.sh"
    --label "org.opencontainers.image.source=${SOURCE_URL%/}"
    --tag "${image_ref}:${short_sha}"
    --tag "${image_ref}:${chart_app_version}"
  )

  set +u
  for extra_tag in "${extra_tags_copy[@]}"; do
    docker_build_args+=(
      --tag "${image_ref}:${extra_tag}"
    )
  done
  set -u

  if [[ "$SKIP_CACHE" != "true" ]]; then
    docker_build_args+=(
      --cache-from "${image_ref}:latest"
    )
  fi

  docker_build_args+=("$CONTEXT_PATH")

  DOCKER_BUILDKIT=1 docker "${docker_build_args[@]}"
  docker push "${image_ref}:${short_sha}"
  docker push "${image_ref}:${chart_app_version}"

  set +u
  for extra_tag in "${extra_tags_copy[@]}"; do
    docker push "${image_ref}:${extra_tag}"
  done
  set -u
fi

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Local equivalent of .github/workflows/replace-text.yaml.

This script replaces the main template placeholders in local files so the repo
can be used without creating a GitHub template copy first.

Replacements:
- {REPLACE_REPO_NAME}
- {REPLACE_ORG_NAME}
- {REPLACE_VCLUSTER_NAME}
- {REPLACE_BASE_DOMAIN}
- {REPLACE_GIT_BASE_URL}
- {REPLACE_GIT_PUBLIC_URL}
- {REPLACE_IMAGE_REPOSITORY_PREFIX}

Usage:
  bash scripts/replace-text-local.sh \
    --repo-name vcp-gitops \
    --org-name vcluster-demos \
    --base-domain vcp.local

Options:
  --repo-name NAME        Optional. Defaults to vcp-gitops.
  --org-name NAME         Optional. Defaults to vcluster-demos.
  --vcluster-name NAME    Optional. Defaults to repo name with trailing -app removed.
  --base-domain DOMAIN    Optional. Defaults to VCP_HOST or vcp.local.
  --git-base-url URL      Optional. Defaults to https://forgejo.vcp.local.
  --git-public-url URL    Optional. Defaults to https://forgejo.vcp.local.
  --image-repository-prefix PREFIX
                          Optional. Defaults to forgejo.vcp.local/<org-name>.
  --include-md            Also replace in Markdown files.
  --dry-run               Print matching files but do not modify them.
  --help                  Show this message.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd" >&2
    exit 1
  fi
}

REPO_NAME="vcp-gitops"
ORG_NAME="vcluster-demos"
VCLUSTER_NAME=""
BASE_DOMAIN=""
GIT_BASE_URL=""
GIT_PUBLIC_URL=""
IMAGE_REPOSITORY_PREFIX=""
INCLUDE_MD="false"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-name)
      REPO_NAME="${2:-}"
      shift 2
      ;;
    --org-name)
      ORG_NAME="${2:-}"
      shift 2
      ;;
    --vcluster-name)
      VCLUSTER_NAME="${2:-}"
      shift 2
      ;;
    --base-domain)
      BASE_DOMAIN="${2:-}"
      shift 2
      ;;
    --git-base-url)
      GIT_BASE_URL="${2:-}"
      shift 2
      ;;
    --git-public-url)
      GIT_PUBLIC_URL="${2:-}"
      shift 2
      ;;
    --image-repository-prefix)
      IMAGE_REPOSITORY_PREFIX="${2:-}"
      shift 2
      ;;
    --include-md)
      INCLUDE_MD="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
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

require_cmd rg
require_cmd perl

if [[ -z "$BASE_DOMAIN" ]]; then
  BASE_DOMAIN="${VCP_HOST:-vcp.local}"
fi

if [[ -z "$VCLUSTER_NAME" ]]; then
  VCLUSTER_NAME="${REPO_NAME%-app}"
fi

if [[ -z "$GIT_BASE_URL" ]]; then
  GIT_BASE_URL="http://${FORGEJO_SERVICE_HOST:-forgejo-http.forgejo.svc.cluster.local:3000}"
fi

if [[ -z "$GIT_PUBLIC_URL" ]]; then
  GIT_PUBLIC_URL="https://${FORGEJO_HOST:-forgejo.vcp.local}"
fi

if [[ -z "$IMAGE_REPOSITORY_PREFIX" ]]; then
  IMAGE_REPOSITORY_PREFIX="${FORGEJO_HOST:-forgejo.vcp.local}/${ORG_NAME}"
fi

declare -a globs
globs+=(--glob '*.yaml' --glob '*.yml' --glob '*.sh')
if [[ "$INCLUDE_MD" == "true" ]]; then
  globs+=(--glob '*.md')
fi

declare -a files=()
while IFS= read -r file; do
  files+=("$file")
done < <(
  rg -l \
    '\{REPLACE_REPO_NAME\}|\{REPLACE_ORG_NAME\}|\{REPLACE_VCLUSTER_NAME\}|\{REPLACE_BASE_DOMAIN\}|\{REPLACE_GIT_BASE_URL\}|\{REPLACE_GIT_PUBLIC_URL\}|\{REPLACE_IMAGE_REPOSITORY_PREFIX\}' \
    . \
    "${globs[@]}" \
    --glob '!.git/*'
)

if [[ "${#files[@]}" -eq 0 ]]; then
  echo "[INFO] No matching files found."
  exit 0
fi

echo "[INFO] Repo name: $REPO_NAME"
echo "[INFO] Org name: $ORG_NAME"
echo "[INFO] vCluster name: $VCLUSTER_NAME"
echo "[INFO] Base domain: $BASE_DOMAIN"
echo "[INFO] Git base URL: $GIT_BASE_URL"
echo "[INFO] Git public URL: $GIT_PUBLIC_URL"
echo "[INFO] Image repository prefix: $IMAGE_REPOSITORY_PREFIX"
echo "[INFO] Files: ${#files[@]}"

if [[ "$DRY_RUN" == "true" ]]; then
  printf '%s\n' "${files[@]}"
  exit 0
fi

export REPO_NAME ORG_NAME VCLUSTER_NAME BASE_DOMAIN GIT_BASE_URL GIT_PUBLIC_URL IMAGE_REPOSITORY_PREFIX

for file in "${files[@]}"; do
  perl -0pi -e '
    s/\{REPLACE_REPO_NAME\}/$ENV{REPO_NAME}/g;
    s/\{REPLACE_ORG_NAME\}/$ENV{ORG_NAME}/g;
    s/\{REPLACE_VCLUSTER_NAME\}/$ENV{VCLUSTER_NAME}/g;
    s/\{REPLACE_BASE_DOMAIN\}/$ENV{BASE_DOMAIN}/g;
    s/\{REPLACE_GIT_BASE_URL\}/$ENV{GIT_BASE_URL}/g;
    s/\{REPLACE_GIT_PUBLIC_URL\}/$ENV{GIT_PUBLIC_URL}/g;
    s/\{REPLACE_IMAGE_REPOSITORY_PREFIX\}/$ENV{IMAGE_REPOSITORY_PREFIX}/g;
  ' "$file"
done

echo "[INFO] Local replacement complete."

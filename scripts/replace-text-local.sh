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

Usage:
  bash scripts/replace-text-local.sh \
    --repo-name vcluster-platform-demo-app-template \
    --org-name loft-demos \
    --base-domain demo.example.com

Options:
  --repo-name NAME        Required. Target repo name.
  --org-name NAME         Required. Target org or owner name.
  --vcluster-name NAME    Optional. Defaults to repo name with trailing -app removed.
  --base-domain DOMAIN    Required. Base domain for example public URLs.
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

REPO_NAME=""
ORG_NAME=""
VCLUSTER_NAME=""
BASE_DOMAIN=""
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

if [[ -z "$REPO_NAME" || -z "$ORG_NAME" || -z "$BASE_DOMAIN" ]]; then
  echo "[ERROR] --repo-name, --org-name, and --base-domain are required." >&2
  usage >&2
  exit 1
fi

if [[ -z "$VCLUSTER_NAME" ]]; then
  VCLUSTER_NAME="${REPO_NAME%-app}"
fi

declare -a globs
globs+=(--glob '*.yaml' --glob '*.yml' --glob '*.sh')
if [[ "$INCLUDE_MD" == "true" ]]; then
  globs+=(--glob '*.md')
fi

mapfile -t files < <(
  rg -l \
    '\{REPLACE_REPO_NAME\}|\{REPLACE_ORG_NAME\}|\{REPLACE_VCLUSTER_NAME\}|\{REPLACE_BASE_DOMAIN\}' \
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
echo "[INFO] Files: ${#files[@]}"

if [[ "$DRY_RUN" == "true" ]]; then
  printf '%s\n' "${files[@]}"
  exit 0
fi

for file in "${files[@]}"; do
  perl -0pi -e '
    s/\{REPLACE_REPO_NAME\}/$ENV{REPO_NAME}/g;
    s/\{REPLACE_ORG_NAME\}/$ENV{ORG_NAME}/g;
    s/\{REPLACE_VCLUSTER_NAME\}/$ENV{VCLUSTER_NAME}/g;
    s/\{REPLACE_BASE_DOMAIN\}/$ENV{BASE_DOMAIN}/g;
  ' "$file"
done

echo "[INFO] Local replacement complete."

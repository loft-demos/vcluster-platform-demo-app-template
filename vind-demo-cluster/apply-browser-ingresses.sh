#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Render and apply the vind browser-facing ingress resources.

This helper keeps the local browser entrypoint separate from internal service
names so later Gateway API changes only need to replace these manifests.

Usage:
  bash vind-demo-cluster/apply-browser-ingresses.sh

  bash vind-demo-cluster/apply-browser-ingresses.sh \
    --vcp-host team-a.vcp.local \
    --argocd-host argocd.team-a.vcp.local \
    --forgejo-host forgejo.team-a.vcp.local

Options:
  --file PATH            Optional. Defaults to vind-demo-cluster/browser-ingresses.yaml.
  --vcp-host HOST        Optional. Defaults to vcp.local.
  --argocd-host HOST     Optional. Defaults to argocd.<vcp-host>.
  --forgejo-host HOST    Optional. Defaults to forgejo.<vcp-host>.
  --help                 Show this message.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd" >&2
    exit 1
  fi
}

FILE="vind-demo-cluster/browser-ingresses.yaml"
VCP_HOST="vcp.local"
ARGOCD_HOST=""
FORGEJO_HOST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      FILE="${2:-}"
      shift 2
      ;;
    --vcp-host)
      VCP_HOST="${2:-}"
      shift 2
      ;;
    --argocd-host)
      ARGOCD_HOST="${2:-}"
      shift 2
      ;;
    --forgejo-host)
      FORGEJO_HOST="${2:-}"
      shift 2
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

require_cmd kubectl
require_cmd mktemp
require_cmd perl

if [[ -z "$ARGOCD_HOST" ]]; then
  ARGOCD_HOST="argocd.${VCP_HOST}"
fi

if [[ -z "$FORGEJO_HOST" ]]; then
  FORGEJO_HOST="forgejo.${VCP_HOST}"
fi

rendered_file="$(mktemp "${TMPDIR:-/tmp}/vind-browser-ingresses.XXXXXX")"
cleanup() {
  rm -f "$rendered_file"
}
trap cleanup EXIT

cp "$FILE" "$rendered_file"

export VCP_HOST ARGOCD_HOST FORGEJO_HOST
perl -0pi -e '
  s/__VCP_HOST__/$ENV{VCP_HOST}/g;
  s/__ARGOCD_HOST__/$ENV{ARGOCD_HOST}/g;
  s/__FORGEJO_HOST__/$ENV{FORGEJO_HOST}/g;
' "$rendered_file"

if ! rg -q '^[[:space:]]*apiVersion:' "$rendered_file"; then
  echo "[INFO] No browser ingress resources to apply."
  exit 0
fi

kubectl apply -f "$rendered_file"

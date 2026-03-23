#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Create or update a Forgejo/Gitea-compatible repository Actions secret.

Usage:
  bash scripts/configure-forgejo-actions-secret.sh \
    --forgejo-url http://forgejo.vcp.local \
    --username demo-admin \
    --password "$FORGEJO_PASSWORD" \
    --owner vcluster-demos \
    --repo vcp-gitops \
    --secret-name FORGEJO_PASSWORD \
    --secret-value "$FORGEJO_PASSWORD"

Options:
  --forgejo-url URL        Base URL for Forgejo, for example http://forgejo.vcp.local
  --username NAME          Forgejo username used for auth when --password is used
  --token VALUE            Forgejo personal access token. Defaults to FORGEJO_TOKEN
  --password VALUE         Forgejo password for basic auth. Defaults to FORGEJO_PASSWORD
  --owner NAME             Repository owner
  --repo NAME              Repository name
  --secret-name VALUE      Actions secret name
  --secret-value VALUE     Actions secret value
  --help                   Show this message
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd" >&2
    exit 1
  fi
}

FORGEJO_URL=""
USERNAME=""
TOKEN="${FORGEJO_TOKEN:-}"
PASSWORD="${FORGEJO_PASSWORD:-}"
OWNER=""
REPO=""
SECRET_NAME=""
SECRET_VALUE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --forgejo-url)
      FORGEJO_URL="${2:-}"
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
    --owner)
      OWNER="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --secret-name)
      SECRET_NAME="${2:-}"
      shift 2
      ;;
    --secret-value)
      SECRET_VALUE="${2:-}"
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

require_cmd curl
require_cmd jq

if [[ -z "$FORGEJO_URL" || -z "$OWNER" || -z "$REPO" || -z "$SECRET_NAME" ]]; then
  echo "[ERROR] --forgejo-url, --owner, --repo, and --secret-name are required." >&2
  usage >&2
  exit 1
fi

if [[ -z "$TOKEN" && ( -z "$USERNAME" || -z "$PASSWORD" ) ]]; then
  echo "[ERROR] Provide either --token or both --username and --password." >&2
  exit 1
fi

API_URL="${FORGEJO_URL%/}/api/v1/repos/${OWNER}/${REPO}/actions/secrets/${SECRET_NAME}"
payload="$(jq -cn --arg data "$SECRET_VALUE" '{data: $data}')"

auth_args=()
if [[ -n "$TOKEN" ]]; then
  auth_args=(-H "Authorization: token $TOKEN")
else
  auth_args=(-u "$USERNAME:$PASSWORD")
fi

status="$(
  curl -sS -o /dev/null -w '%{http_code}' \
    -X PUT \
    "${auth_args[@]}" \
    -H "Content-Type: application/json" \
    "$API_URL" \
    -d "$payload"
)"

case "$status" in
  201)
    echo "[INFO] Created Actions secret '${SECRET_NAME}' in ${OWNER}/${REPO}"
    ;;
  204)
    echo "[INFO] Updated Actions secret '${SECRET_NAME}' in ${OWNER}/${REPO}"
    ;;
  *)
    echo "[ERROR] Forgejo returned HTTP ${status} while setting Actions secret '${SECRET_NAME}' in ${OWNER}/${REPO}" >&2
    exit 1
    ;;
esac

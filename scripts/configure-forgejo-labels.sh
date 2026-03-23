#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Create or update a single label in a Forgejo/Gitea-compatible repository.

Usage:
  bash scripts/configure-forgejo-labels.sh \
    --forgejo-url http://forgejo.vcp.local \
    --username demo-admin \
    --token "$FORGEJO_TOKEN" \
    --owner vcluster-demos \
    --repo vcp-gitops \
    --label-name 'deploy/flux-vcluster-preview' \
    --label-color 'c5def5' \
    --label-description 'PR preview vCluster instances with a matrix of Kubernetes versions via Flux'

Options:
  --forgejo-url URL        Base URL for Forgejo, for example http://forgejo.vcp.local
  --username NAME          Forgejo username used for auth when --password is used
  --token VALUE            Forgejo personal access token. Defaults to FORGEJO_TOKEN
  --password VALUE         Forgejo password for basic auth. Defaults to FORGEJO_PASSWORD
  --owner NAME             Repository owner
  --repo NAME              Repository name
  --label-name VALUE       Label name
  --label-color VALUE      Label hex color without leading #, for example ee7d3b
  --label-description VALUE
                           Optional label description
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

api_request() {
  local method="$1"
  local url="$2"
  local data="${3:-}"

  local auth_args=()
  if [[ -n "$TOKEN" ]]; then
    auth_args=(-H "Authorization: token $TOKEN")
  else
    auth_args=(-u "$USERNAME:$PASSWORD")
  fi

  if [[ -n "$data" ]]; then
    curl -fsS \
      -X "$method" \
      "${auth_args[@]}" \
      -H "Content-Type: application/json" \
      "$url" \
      -d "$data"
  else
    curl -fsS \
      -X "$method" \
      "${auth_args[@]}" \
      "$url"
  fi
}

FORGEJO_URL=""
USERNAME=""
TOKEN="${FORGEJO_TOKEN:-}"
PASSWORD="${FORGEJO_PASSWORD:-}"
OWNER=""
REPO=""
LABEL_NAME=""
LABEL_COLOR=""
LABEL_DESCRIPTION=""

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
    --label-name)
      LABEL_NAME="${2:-}"
      shift 2
      ;;
    --label-color)
      LABEL_COLOR="${2:-}"
      shift 2
      ;;
    --label-description)
      LABEL_DESCRIPTION="${2:-}"
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

if [[ -z "$FORGEJO_URL" || -z "$OWNER" || -z "$REPO" || -z "$LABEL_NAME" || -z "$LABEL_COLOR" ]]; then
  echo "[ERROR] --forgejo-url, --owner, --repo, --label-name, and --label-color are required." >&2
  usage >&2
  exit 1
fi

if [[ -z "$TOKEN" && ( -z "$USERNAME" || -z "$PASSWORD" ) ]]; then
  echo "[ERROR] Provide either --token or both --username and --password." >&2
  exit 1
fi

# Forgejo expects color with a leading #
color="#${LABEL_COLOR#\#}"

API_BASE="${FORGEJO_URL%/}/api/v1"
LABELS_URL="${API_BASE}/repos/${OWNER}/${REPO}/labels"

payload="$(
  jq -cn \
    --arg name "$LABEL_NAME" \
    --arg color "$color" \
    --arg description "$LABEL_DESCRIPTION" \
    '{name: $name, color: $color} + (if $description != "" then {description: $description} else {} end)'
)"

existing_labels="$(api_request GET "$LABELS_URL")"
existing_id="$(
  jq -r \
    --arg name "$LABEL_NAME" \
    '.[] | select(.name == $name) | .id' \
    <<<"$existing_labels" | head -n 1
)"

if [[ -n "$existing_id" ]]; then
  echo "[INFO] Updating label '$LABEL_NAME' (id: $existing_id) in ${OWNER}/${REPO}"
  api_request PATCH "${LABELS_URL}/${existing_id}" "$payload" >/dev/null
else
  echo "[INFO] Creating label '$LABEL_NAME' in ${OWNER}/${REPO}"
  api_request POST "$LABELS_URL" "$payload" >/dev/null
fi

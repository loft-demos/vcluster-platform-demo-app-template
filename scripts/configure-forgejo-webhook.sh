#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Create or update a Forgejo/Gitea-compatible repository webhook.

Usage:
  bash scripts/configure-forgejo-webhook.sh \
    --forgejo-url http://forgejo.vcp.local \
    --username demo-admin \
    --token "$FORGEJO_TOKEN" \
    --owner vcluster-demos \
    --repo vcp-gitops \
    --webhook-url http://argocd-applicationset-controller.argocd.svc.cluster.local:7000/api/webhook \
    --type gitea \
    --events pull_request

Options:
  --forgejo-url URL        Base URL for Forgejo, for example http://forgejo.vcp.local
  --username NAME          Forgejo username used for auth when --password is used
  --token VALUE            Forgejo personal access token. Defaults to FORGEJO_TOKEN
  --password VALUE         Forgejo password for basic auth. Defaults to FORGEJO_PASSWORD
  --owner NAME             Repository owner
  --repo NAME              Repository name
  --webhook-url URL        Destination webhook URL
  --type TYPE              Webhook type. Default: gogs
  --events LIST            Comma-separated event list. Default: push
  --content-type VALUE     Webhook content type. Default: json
  --secret VALUE           Optional webhook shared secret
  --authorization-header VALUE
                           Optional Authorization header sent by Forgejo
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
WEBHOOK_URL=""
HOOK_TYPE="gogs"
EVENTS_CSV="push"
CONTENT_TYPE="json"
WEBHOOK_SECRET=""
AUTHORIZATION_HEADER=""

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
    --webhook-url)
      WEBHOOK_URL="${2:-}"
      shift 2
      ;;
    --type)
      HOOK_TYPE="${2:-}"
      shift 2
      ;;
    --events)
      EVENTS_CSV="${2:-}"
      shift 2
      ;;
    --content-type)
      CONTENT_TYPE="${2:-}"
      shift 2
      ;;
    --secret)
      WEBHOOK_SECRET="${2:-}"
      shift 2
      ;;
    --authorization-header)
      AUTHORIZATION_HEADER="${2:-}"
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

if [[ -z "$FORGEJO_URL" || -z "$OWNER" || -z "$REPO" || -z "$WEBHOOK_URL" ]]; then
  echo "[ERROR] --forgejo-url, --owner, --repo, and --webhook-url are required." >&2
  usage >&2
  exit 1
fi

if [[ -z "$TOKEN" && ( -z "$USERNAME" || -z "$PASSWORD" ) ]]; then
  echo "[ERROR] Provide either --token or both --username and --password." >&2
  exit 1
fi

API_BASE="${FORGEJO_URL%/}/api/v1"
HOOKS_URL="${API_BASE}/repos/${OWNER}/${REPO}/hooks"

events_json="$(jq -cn --arg csv "$EVENTS_CSV" '$csv | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))')"
hook_config="$(
  jq -cn \
    --arg url "$WEBHOOK_URL" \
    --arg content_type "$CONTENT_TYPE" \
    --arg secret "$WEBHOOK_SECRET" \
    '{
      url: $url,
      content_type: $content_type
    } + (if $secret != "" then {secret: $secret} else {} end)'
)"

payload="$(
  jq -cn \
    --arg type "$HOOK_TYPE" \
    --argjson active true \
    --arg authorization_header "$AUTHORIZATION_HEADER" \
    --argjson events "$events_json" \
    --argjson config "$hook_config" \
    '{
      type: $type,
      active: $active,
      events: $events,
      config: $config
    } + (if $authorization_header != "" then {authorization_header: $authorization_header} else {} end)'
)"

existing_hooks="$(api_request GET "$HOOKS_URL")"
existing_id="$(
  jq -r \
    --arg type "$HOOK_TYPE" \
    --arg url "$WEBHOOK_URL" \
    '.[] | select(.type == $type and ((.config.url // .url // "") == $url)) | .id' \
    <<<"$existing_hooks" | head -n 1
)"

if [[ -n "$existing_id" ]]; then
  echo "[INFO] Updating webhook $existing_id for ${OWNER}/${REPO} -> ${WEBHOOK_URL}"
  api_request PATCH "${HOOKS_URL}/${existing_id}" "$payload" >/dev/null
else
  echo "[INFO] Creating webhook for ${OWNER}/${REPO} -> ${WEBHOOK_URL}"
  api_request POST "$HOOKS_URL" "$payload" >/dev/null
fi

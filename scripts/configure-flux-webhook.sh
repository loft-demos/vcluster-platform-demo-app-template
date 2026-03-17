#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Register a Forgejo webhook for the Flux pr-github-receiver.

Looks up the Receiver's dynamic webhook path from the cluster, then calls
configure-forgejo-webhook.sh with the full URL. Safe to re-run — the webhook
script will update an existing hook rather than create a duplicate.

Usage:
  bash scripts/configure-flux-webhook.sh \
    --forgejo-url https://forgejo.vcp.local \
    --username demo-admin \
    --token "$FORGEJO_TOKEN" \
    --owner vcluster-demos \
    --repo vcp-gitops \
    --vcluster-name vcp-gitops \
    --base-domain vcp.local

Options:
  --forgejo-url URL        Base URL for Forgejo, for example https://forgejo.vcp.local
  --username NAME          Forgejo username used for auth when --password is used
  --token VALUE            Forgejo personal access token. Defaults to FORGEJO_TOKEN
  --password VALUE         Forgejo password for basic auth. Defaults to FORGEJO_PASSWORD
  --owner NAME             Repository owner
  --repo NAME              Repository name
  --vcluster-name NAME     vCluster name used in the ingress hostname
  --base-domain DOMAIN     Base domain used in the ingress hostname
  --receiver-namespace NS  Namespace of the Flux Receiver. Default: p-auth-core
  --receiver-name NAME     Name of the Flux Receiver. Default: pr-github-receiver
  --webhook-secret VALUE   Optional shared secret for HMAC signature verification.
                           If provided, the Forgejo webhook and the Receiver secret
                           must use the same value.
  --timeout SECONDS        Seconds to wait for the Receiver webhook path. Default: 1800
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
VCLUSTER_NAME=""
BASE_DOMAIN=""
RECEIVER_NAMESPACE="p-auth-core"
RECEIVER_NAME="pr-github-receiver"
RECEIVER_SECRET_NAME="pr-github-receiver-token"
WEBHOOK_SECRET=""
TIMEOUT=1800

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
    --vcluster-name)
      VCLUSTER_NAME="${2:-}"
      shift 2
      ;;
    --base-domain)
      BASE_DOMAIN="${2:-}"
      shift 2
      ;;
    --receiver-namespace)
      RECEIVER_NAMESPACE="${2:-}"
      shift 2
      ;;
    --receiver-name)
      RECEIVER_NAME="${2:-}"
      shift 2
      ;;
    --webhook-secret)
      WEBHOOK_SECRET="${2:-}"
      shift 2
      ;;
    --receiver-secret-name)
      RECEIVER_SECRET_NAME="${2:-}"
      shift 2
      ;;
    --timeout)
      TIMEOUT="${2:-}"
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
require_cmd bash

if [[ -z "$FORGEJO_URL" || -z "$OWNER" || -z "$REPO" || -z "$VCLUSTER_NAME" || -z "$BASE_DOMAIN" ]]; then
  echo "[ERROR] --forgejo-url, --owner, --repo, --vcluster-name, and --base-domain are required." >&2
  usage >&2
  exit 1
fi

if [[ -z "$TOKEN" && ( -z "$USERNAME" || -z "$PASSWORD" ) ]]; then
  echo "[ERROR] Provide either --token or both --username and --password." >&2
  exit 1
fi

# Wait for the Receiver namespace
echo "[INFO] Waiting for namespace ${RECEIVER_NAMESPACE}..."
deadline=$(( $(date +%s) + TIMEOUT ))
until kubectl get namespace "$RECEIVER_NAMESPACE" >/dev/null 2>&1; do
  if [[ $(date +%s) -ge $deadline ]]; then
    echo "[ERROR] Timed out waiting for namespace ${RECEIVER_NAMESPACE}." >&2
    exit 1
  fi
  sleep 5
done

# Wait for the Receiver to report its webhook path
echo "[INFO] Waiting for ${RECEIVER_NAME}.status.webhookPath in ${RECEIVER_NAMESPACE}..."
webhook_path=""
until [[ -n "$webhook_path" ]]; do
  if [[ $(date +%s) -ge $deadline ]]; then
    echo "[ERROR] Timed out waiting for Flux Receiver webhook path." >&2
    exit 1
  fi
  webhook_path="$(kubectl -n "$RECEIVER_NAMESPACE" get receiver "$RECEIVER_NAME" \
    -o jsonpath='{.status.webhookPath}' 2>/dev/null || true)"
  [[ -n "$webhook_path" ]] || sleep 5
done

webhook_url="http://flux-webhook-${VCLUSTER_NAME}.${BASE_DOMAIN}${webhook_path}"
echo "[INFO] Flux webhook URL: ${webhook_url}"

# If no webhook secret was provided on the CLI, try to read the token that
# bootstrap already stored in the cluster secret. This makes the script safe
# to re-run after the initial bootstrap without needing to know the token.
if [[ -z "$WEBHOOK_SECRET" ]]; then
  WEBHOOK_SECRET="$(
    kubectl -n "$RECEIVER_NAMESPACE" get secret "$RECEIVER_SECRET_NAME" \
      -o jsonpath='{.data.token}' 2>/dev/null \
      | base64 --decode 2>/dev/null || true
  )"
  if [[ -n "$WEBHOOK_SECRET" ]]; then
    echo "[INFO] Loaded webhook secret from cluster secret ${RECEIVER_SECRET_NAME}."
  fi
fi

auth_args=()
if [[ -n "$TOKEN" ]]; then
  auth_args=(--token "$TOKEN")
else
  auth_args=(--username "$USERNAME" --password "$PASSWORD")
fi

secret_args=()
if [[ -n "$WEBHOOK_SECRET" ]]; then
  secret_args=(--secret "$WEBHOOK_SECRET")
fi

bash "$(dirname "$0")/configure-forgejo-webhook.sh" \
  --forgejo-url "$FORGEJO_URL" \
  "${auth_args[@]}" \
  --owner "$OWNER" \
  --repo "$REPO" \
  --webhook-url "$webhook_url" \
  --type gitea \
  --events push,pull_request \
  "${secret_args[@]}"

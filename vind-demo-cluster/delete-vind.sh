#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Delete a vind cluster created for this repo and clean up the OrbStack adapter.

This helper:
1. stops the per-cluster OrbStack/Caddy adapter if present
2. deletes the vind cluster
3. optionally removes the generated OrbStack env file

Usage:
  bash vind-demo-cluster/delete-vind.sh

  bash vind-demo-cluster/delete-vind.sh \
    --cluster-name team-a \
    --vcp-host team-a.vcp.local

Options:
  --cluster-name NAME       Optional. Defaults to vcp.
  --vcp-host HOST           Optional. Defaults to vcp.local.
  --argocd-host HOST        Optional. Defaults to argocd.<vcp-host>.
  --forgejo-host HOST       Optional. Defaults to forgejo.<vcp-host>.
  --orbstack-env-file PATH  Optional. Defaults to orbstack-domains/.env for vcp,
                            or .env.<cluster-name> for other clusters.
                            If that env file still exists, its host values are
                            reused automatically.
  --skip-orbstack-domains   Optional. Skip OrbStack/Caddy cleanup.
  --keep-orbstack-env       Optional. Keep the generated env file.
  --help                    Show this message.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd" >&2
    exit 1
  fi
}

CLUSTER_NAME="vcp"
VCP_HOST="vcp.local"
ARGOCD_HOST=""
FORGEJO_HOST=""
ORBSTACK_ENV_FILE=""
SKIP_ORBSTACK_DOMAINS="false"
KEEP_ORBSTACK_ENV="false"
COMPOSE_DIR="vind-demo-cluster/orbstack-domains"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster-name)
      CLUSTER_NAME="${2:-}"
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
    --orbstack-env-file)
      ORBSTACK_ENV_FILE="${2:-}"
      shift 2
      ;;
    --skip-orbstack-domains)
      SKIP_ORBSTACK_DOMAINS="true"
      shift
      ;;
    --keep-orbstack-env)
      KEEP_ORBSTACK_ENV="true"
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

require_cmd vcluster
require_cmd docker
require_cmd mktemp

if [[ -z "$ARGOCD_HOST" ]]; then
  ARGOCD_HOST="argocd.${VCP_HOST}"
fi

if [[ -z "$FORGEJO_HOST" ]]; then
  FORGEJO_HOST="forgejo.${VCP_HOST}"
fi

if [[ -z "$ORBSTACK_ENV_FILE" ]]; then
  if [[ "$CLUSTER_NAME" == "vcp" ]]; then
    ORBSTACK_ENV_FILE="${COMPOSE_DIR}/.env"
  else
    ORBSTACK_ENV_FILE="${COMPOSE_DIR}/.env.${CLUSTER_NAME}"
  fi
fi

if [[ "$SKIP_ORBSTACK_DOMAINS" != "true" ]]; then
  env_file_for_down="$ORBSTACK_ENV_FILE"
  temp_env_file=""

  if [[ ! -f "$env_file_for_down" ]]; then
    temp_env_file="$(mktemp "${TMPDIR:-/tmp}/vind-orbstack-down.XXXXXX")"
    cat >"$temp_env_file" <<EOF
VIND_DOCKER_NETWORK=vcluster.${CLUSTER_NAME}
VCP_HOST=${VCP_HOST}
ARGOCD_HOST=${ARGOCD_HOST}
FORGEJO_HOST=${FORGEJO_HOST}
VCP_UPSTREAM=vcluster.lb.${CLUSTER_NAME}.loft.vcluster-platform:80
ARGOCD_UPSTREAM=vcluster.lb.${CLUSTER_NAME}.argocd-server.argocd:80
FORGEJO_UPSTREAM=vcluster.lb.${CLUSTER_NAME}.forgejo-http.forgejo:3000
EOF
    env_file_for_down="$temp_env_file"
  fi

  docker compose \
    --project-directory "$COMPOSE_DIR" \
    --project-name "vind-local-domains-${CLUSTER_NAME}" \
    --env-file "$env_file_for_down" \
    -f "${COMPOSE_DIR}/compose.yaml" \
    down --remove-orphans >/dev/null 2>&1 || true

  if [[ -n "$temp_env_file" ]]; then
    rm -f "$temp_env_file"
  fi
fi

vcluster delete "$CLUSTER_NAME"

if [[ "$KEEP_ORBSTACK_ENV" != "true" && -f "$ORBSTACK_ENV_FILE" ]]; then
  rm -f "$ORBSTACK_ENV_FILE"
fi

cat <<EOF

[INFO] Deleted vind cluster '$CLUSTER_NAME'.

OrbStack adapter:
- project: vind-local-domains-${CLUSTER_NAME}
- env file: ${ORBSTACK_ENV_FILE}

EOF

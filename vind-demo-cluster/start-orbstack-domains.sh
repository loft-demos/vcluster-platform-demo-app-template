#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Start or update the OrbStack local-domain adapter for a vind environment.

This helper:
1. discovers the current LoadBalancer upstreams for Argo CD and vCluster Platform
2. writes a per-cluster env file for the OrbStack adapter
3. starts or updates the Caddy-based adapter with docker compose

Usage:
  bash vind-demo-cluster/start-orbstack-domains.sh

  bash vind-demo-cluster/start-orbstack-domains.sh \
    --cluster-name team-a \
    --vcp-host team-a.vcp.local \
    --argocd-host argocd.team-a.vcp.local \
    --forgejo-host forgejo.team-a.vcp.local

Options:
  --cluster-name NAME       Optional. Defaults to vcp.
  --vcp-host HOST           Optional. Defaults to vcp.local.
  --argocd-host HOST        Optional. Defaults to argocd.<vcp-host>.
  --forgejo-host HOST       Optional. Defaults to forgejo.<vcp-host>.
  --vcp-upstream HOST:PORT  Optional. Skip auto-discovery for vCP.
  --argocd-upstream HOST:PORT
                            Optional. Skip auto-discovery for Argo CD.
  --forgejo-upstream HOST:PORT
                            Optional. Defaults to 127.0.0.1:3000.
  --env-file PATH           Optional. Defaults to orbstack-domains/.env.<cluster-name>.
  --docker-network NAME     Optional. Defaults to vcluster.<cluster-name>.
  --timeout SECONDS         Optional. Defaults to 120.
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

discover_lb_upstream() {
  local namespace="$1"
  local service="$2"
  local timeout_seconds="$3"
  local started_at
  started_at="$(date +%s)"

  while true; do
    local hostname ip port now
    hostname="$(kubectl -n "$namespace" get svc "$service" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    ip="$(kubectl -n "$namespace" get svc "$service" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    port="$(kubectl -n "$namespace" get svc "$service" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)"

    if [[ -n "$hostname" && -n "$port" ]]; then
      printf '%s:%s\n' "$hostname" "$port"
      return 0
    fi

    if [[ -n "$ip" && -n "$port" ]]; then
      printf '%s:%s\n' "$ip" "$port"
      return 0
    fi

    now="$(date +%s)"
    if (( now - started_at >= timeout_seconds )); then
      return 1
    fi

    sleep 2
  done
}

CLUSTER_NAME="vcp"
VCP_HOST="vcp.local"
ARGOCD_HOST=""
FORGEJO_HOST=""
VCP_UPSTREAM=""
ARGOCD_UPSTREAM=""
FORGEJO_UPSTREAM="127.0.0.1:3000"
ENV_FILE=""
VIND_DOCKER_NETWORK=""
TIMEOUT_SECONDS="120"
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
    --vcp-upstream)
      VCP_UPSTREAM="${2:-}"
      shift 2
      ;;
    --argocd-upstream)
      ARGOCD_UPSTREAM="${2:-}"
      shift 2
      ;;
    --forgejo-upstream)
      FORGEJO_UPSTREAM="${2:-}"
      shift 2
      ;;
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      ;;
    --docker-network)
      VIND_DOCKER_NETWORK="${2:-}"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2:-}"
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
require_cmd docker

if [[ -z "$ARGOCD_HOST" ]]; then
  ARGOCD_HOST="argocd.${VCP_HOST}"
fi

if [[ -z "$FORGEJO_HOST" ]]; then
  FORGEJO_HOST="forgejo.${VCP_HOST}"
fi

if [[ -z "$VIND_DOCKER_NETWORK" ]]; then
  VIND_DOCKER_NETWORK="vcluster.${CLUSTER_NAME}"
fi

if [[ -z "$ENV_FILE" ]]; then
  ENV_FILE="${COMPOSE_DIR}/.env.${CLUSTER_NAME}"
fi

if ! docker network inspect "$VIND_DOCKER_NETWORK" >/dev/null 2>&1; then
  echo "[ERROR] Docker network not found: $VIND_DOCKER_NETWORK" >&2
  echo "[ERROR] Start the vind cluster first or override --docker-network." >&2
  exit 1
fi

if [[ -z "$ARGOCD_UPSTREAM" ]]; then
  ARGOCD_UPSTREAM="$(discover_lb_upstream argocd argocd-server "$TIMEOUT_SECONDS")" || {
    echo "[ERROR] Could not discover the Argo CD LoadBalancer hostname." >&2
    echo "[ERROR] Override it with --argocd-upstream if needed." >&2
    exit 1
  }
fi

if [[ -z "$VCP_UPSTREAM" ]]; then
  VCP_UPSTREAM="$(discover_lb_upstream vcluster-platform vcluster-platform "$TIMEOUT_SECONDS")" || {
    echo "[ERROR] Could not discover the vCluster Platform LoadBalancer hostname." >&2
    echo "[ERROR] Override it with --vcp-upstream if needed." >&2
    exit 1
  }
fi

mkdir -p "$(dirname "$ENV_FILE")"

cat >"$ENV_FILE" <<EOF
LOCAL_BASE_DOMAIN=${VCP_HOST#*.}
VIND_DOCKER_NETWORK=${VIND_DOCKER_NETWORK}
VCP_HOST=${VCP_HOST}
ARGOCD_HOST=${ARGOCD_HOST}
FORGEJO_HOST=${FORGEJO_HOST}
VCP_UPSTREAM=${VCP_UPSTREAM}
ARGOCD_UPSTREAM=${ARGOCD_UPSTREAM}
FORGEJO_UPSTREAM=${FORGEJO_UPSTREAM}
EOF

echo "[INFO] Wrote ${ENV_FILE}"
echo "[INFO] vCP upstream: ${VCP_UPSTREAM}"
echo "[INFO] Argo CD upstream: ${ARGOCD_UPSTREAM}"
echo "[INFO] Forgejo upstream: ${FORGEJO_UPSTREAM}"

docker compose \
  --project-directory "$COMPOSE_DIR" \
  --project-name "vind-local-domains-${CLUSTER_NAME}" \
  --env-file "$ENV_FILE" \
  -f "${COMPOSE_DIR}/compose.yaml" \
  up -d

cat <<EOF

[INFO] OrbStack local-domain adapter is ready.

URLs:
- https://${VCP_HOST}
- https://${ARGOCD_HOST}
- https://${FORGEJO_HOST}

EOF

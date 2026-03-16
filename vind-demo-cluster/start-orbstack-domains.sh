#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Start or update the OrbStack local-domain adapter for a vind environment.

This helper:
1. derives the HAProxy LoadBalancer upstreams for Argo CD and vCluster Platform
   on the `vind` Docker network
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
  --vcp-upstream HOST[:PORT] Optional. Override the default vCP HAProxy upstream.
  --argocd-upstream HOST:PORT
                            Optional. Override the default Argo CD HAProxy upstream.
  --forgejo-upstream HOST[:PORT]
                            Optional. Override the default Forgejo HAProxy upstream.
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

CLUSTER_NAME="vcp"
VCP_HOST="vcp.local"
ARGOCD_HOST=""
FORGEJO_HOST=""
VCP_UPSTREAM=""
ARGOCD_UPSTREAM=""
FORGEJO_UPSTREAM=""
INGRESS_WILDCARD_HOST=""
INGRESS_UPSTREAM=""
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
    --ingress-upstream)
      INGRESS_UPSTREAM="${2:-}"
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

require_cmd docker

if [[ -z "$ARGOCD_HOST" ]]; then
  ARGOCD_HOST="argocd.${VCP_HOST}"
fi

if [[ -z "$FORGEJO_HOST" ]]; then
  FORGEJO_HOST="forgejo.${VCP_HOST}"
fi

if [[ -z "$INGRESS_WILDCARD_HOST" ]]; then
  INGRESS_WILDCARD_HOST="*.${VCP_HOST}"
fi

if [[ -z "$VIND_DOCKER_NETWORK" ]]; then
  VIND_DOCKER_NETWORK="vcluster.${CLUSTER_NAME}"
fi

if [[ -z "$ENV_FILE" ]]; then
  if [[ "$CLUSTER_NAME" == "vcp" ]]; then
    ENV_FILE="${COMPOSE_DIR}/.env"
  else
    ENV_FILE="${COMPOSE_DIR}/.env.${CLUSTER_NAME}"
  fi
fi

if ! docker network inspect "$VIND_DOCKER_NETWORK" >/dev/null 2>&1; then
  echo "[ERROR] Docker network not found: $VIND_DOCKER_NETWORK" >&2
  echo "[ERROR] Start the vind cluster first or override --docker-network." >&2
  exit 1
fi

if [[ -z "$ARGOCD_UPSTREAM" ]]; then
  ARGOCD_UPSTREAM="vcluster.lb.${CLUSTER_NAME}.argocd-server.argocd:80"
fi

if [[ -z "$VCP_UPSTREAM" ]]; then
  VCP_UPSTREAM="vcluster.lb.${CLUSTER_NAME}.loft.vcluster-platform:443"
fi

if [[ -z "$FORGEJO_UPSTREAM" ]]; then
  FORGEJO_UPSTREAM="vcluster.lb.${CLUSTER_NAME}.forgejo-http.forgejo:3000"
fi

if [[ -z "$INGRESS_UPSTREAM" ]]; then
  INGRESS_UPSTREAM="vcluster.lb.${CLUSTER_NAME}.ingress-nginx-controller.ingress-nginx:80"
fi

mkdir -p "$(dirname "$ENV_FILE")"

cat >"$ENV_FILE" <<EOF
LOCAL_BASE_DOMAIN=${VCP_HOST#*.}
VIND_DOCKER_NETWORK=${VIND_DOCKER_NETWORK}
VCP_HOST=${VCP_HOST}
ARGOCD_HOST=${ARGOCD_HOST}
FORGEJO_HOST=${FORGEJO_HOST}
INGRESS_WILDCARD_HOST=${INGRESS_WILDCARD_HOST}
VCP_UPSTREAM=${VCP_UPSTREAM}
ARGOCD_UPSTREAM=${ARGOCD_UPSTREAM}
FORGEJO_UPSTREAM=${FORGEJO_UPSTREAM}
INGRESS_UPSTREAM=${INGRESS_UPSTREAM}
EOF

echo "[INFO] Wrote ${ENV_FILE}"
echo "[INFO] vCP upstream: ${VCP_UPSTREAM}"
echo "[INFO] Argo CD upstream: ${ARGOCD_UPSTREAM}"
echo "[INFO] Forgejo upstream: ${FORGEJO_UPSTREAM}"
echo "[INFO] Wildcard ingress upstream: ${INGRESS_UPSTREAM}"

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
- https://<app>.${VCP_HOST}

EOF

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Create or upgrade the local vind cluster for this repo.

This helper renders vind-demo-cluster/vcluster.yaml with the required
vCluster Platform install settings, then runs:

  vcluster create <cluster-name> --driver docker --upgrade --add=false --values <rendered-values>

Usage:
  LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/install-vind.sh

  bash vind-demo-cluster/install-vind.sh \
    --license-token "$TOKEN" \
    --vcp-version 4.7.1 \
    --vcp-host vcp.local \
    --worker-nodes 2

Options:
  --cluster-name NAME    Optional. Defaults to vcp.
  --values-file PATH     Optional. Defaults to vind-demo-cluster/vcluster.yaml.
  --license-token TOKEN  Required unless LICENSE_TOKEN is already exported.
  --vcp-version VERSION  Optional. Defaults to 4.7.1.
  --control-plane-nodes COUNT
                         Optional. Defaults to 1. This vind config currently
                         supports exactly one control plane node.
  --worker-nodes COUNT   Optional. Defaults to 2.
  --vcp-host HOST        Optional. Defaults to vcp.local.
  --argocd-host HOST     Optional. Defaults to argocd.<vcp-host>.
  --forgejo-host HOST    Optional. Defaults to forgejo.<vcp-host>.
  --forgejo-admin-user NAME
                         Optional. Defaults to demo-admin.
  --forgejo-admin-password VALUE
                         Optional. Defaults to FORGEJO_ADMIN_PASSWORD or
                         vcluster-demo-admin.
  --sleep-time-zone TZ   Optional. Defaults to America/New_York.
  --orbstack-env-file PATH
                         Optional. Defaults to orbstack-domains/.env.<cluster-name>.
  --skip-orbstack-domains
                         Optional. Skip automatic OrbStack domain setup.
  --skip-summary         Optional. Skip the final next-steps summary.
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

CLUSTER_NAME="vcp"
VALUES_FILE="vind-demo-cluster/vcluster.yaml"
LICENSE_TOKEN="${LICENSE_TOKEN:-}"
VCP_VERSION="${VCP_VERSION:-4.7.1}"
CONTROL_PLANE_NODE_COUNT="${CONTROL_PLANE_NODE_COUNT:-1}"
WORKER_NODE_COUNT="${WORKER_NODE_COUNT:-2}"
VCP_HOST="${VCP_HOST:-vcp.local}"
ARGOCD_HOST=""
FORGEJO_HOST=""
FORGEJO_ADMIN_USER="${FORGEJO_ADMIN_USER:-demo-admin}"
FORGEJO_ADMIN_PASSWORD="${FORGEJO_ADMIN_PASSWORD:-vcluster-demo-admin}"
SLEEP_TIME_ZONE="${SLEEP_TIME_ZONE:-America/New_York}"
ORBSTACK_ENV_FILE=""
SKIP_ORBSTACK_DOMAINS="false"
SKIP_SUMMARY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster-name)
      CLUSTER_NAME="${2:-}"
      shift 2
      ;;
    --values-file)
      VALUES_FILE="${2:-}"
      shift 2
      ;;
    --license-token)
      LICENSE_TOKEN="${2:-}"
      shift 2
      ;;
    --vcp-version)
      VCP_VERSION="${2:-}"
      shift 2
      ;;
    --control-plane-nodes)
      CONTROL_PLANE_NODE_COUNT="${2:-}"
      shift 2
      ;;
    --worker-nodes)
      WORKER_NODE_COUNT="${2:-}"
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
    --forgejo-admin-user)
      FORGEJO_ADMIN_USER="${2:-}"
      shift 2
      ;;
    --forgejo-admin-password)
      FORGEJO_ADMIN_PASSWORD="${2:-}"
      shift 2
      ;;
    --sleep-time-zone)
      SLEEP_TIME_ZONE="${2:-}"
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
    --skip-summary)
      SKIP_SUMMARY="true"
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
require_cmd perl
require_cmd mktemp

if [[ -z "$LICENSE_TOKEN" ]]; then
  echo "[ERROR] A vCluster Platform license token is required." >&2
  echo "[ERROR] Provide it with --license-token or export LICENSE_TOKEN." >&2
  exit 1
fi

if [[ ! "$CONTROL_PLANE_NODE_COUNT" =~ ^[0-9]+$ || "$CONTROL_PLANE_NODE_COUNT" -ne 1 ]]; then
  echo "[ERROR] --control-plane-nodes must be 1 for this vind configuration." >&2
  exit 1
fi

if [[ ! "$WORKER_NODE_COUNT" =~ ^[0-9]+$ ]]; then
  echo "[ERROR] --worker-nodes must be a non-negative integer." >&2
  exit 1
fi

if [[ -z "$ARGOCD_HOST" ]]; then
  ARGOCD_HOST="argocd.${VCP_HOST}"
fi

if [[ -z "$FORGEJO_HOST" ]]; then
  FORGEJO_HOST="forgejo.${VCP_HOST}"
fi

vcp_domain_prefix="${VCP_HOST%%.*}"
if [[ "$VCP_HOST" == *.* ]]; then
  vcp_domain="${VCP_HOST#*.}"
else
  vcp_domain="local"
fi

if [[ -z "$ORBSTACK_ENV_FILE" ]]; then
  if [[ "$CLUSTER_NAME" == "vcp" ]]; then
    ORBSTACK_ENV_FILE="vind-demo-cluster/orbstack-domains/.env"
  else
    ORBSTACK_ENV_FILE="vind-demo-cluster/orbstack-domains/.env.${CLUSTER_NAME}"
  fi
fi

worker_nodes_yaml="      []"
if [[ "$WORKER_NODE_COUNT" -gt 0 ]]; then
  worker_nodes_yaml=""
  for worker_index in $(seq 1 "$WORKER_NODE_COUNT"); do
    worker_nodes_yaml="${worker_nodes_yaml}      - name: worker-${worker_index}
"
  done
  worker_nodes_yaml="${worker_nodes_yaml%$'\n'}"
fi

rendered_values="$(mktemp "${TMPDIR:-/tmp}/vind-values.XXXXXX")"
cleanup() {
  rm -f "$rendered_values"
}
trap cleanup EXIT

cp "$VALUES_FILE" "$rendered_values"

export LICENSE_TOKEN VCP_VERSION VCP_HOST FORGEJO_HOST FORGEJO_ADMIN_USER FORGEJO_ADMIN_PASSWORD
export VCP_DOMAIN_PREFIX="$vcp_domain_prefix" VCP_DOMAIN="$vcp_domain"
export VIND_DOCKER_NODES="$worker_nodes_yaml"
perl -0pi -e '
  s/__VCP_LICENSE_TOKEN__/$ENV{LICENSE_TOKEN}/g;
  s/__VCP_PLATFORM_VERSION__/$ENV{VCP_VERSION}/g;
  s/__VCP_LOFT_HOST__/$ENV{VCP_HOST}/g;
  s/__VCP_DOMAIN_PREFIX__/$ENV{VCP_DOMAIN_PREFIX}/g;
  s/__VCP_DOMAIN__/$ENV{VCP_DOMAIN}/g;
  s/__FORGEJO_HOST__/$ENV{FORGEJO_HOST}/g;
  s/__FORGEJO_ADMIN_USER__/$ENV{FORGEJO_ADMIN_USER}/g;
  s/__FORGEJO_ADMIN_PASSWORD__/$ENV{FORGEJO_ADMIN_PASSWORD}/g;
  s/__VIND_DOCKER_NODES__/$ENV{VIND_DOCKER_NODES}/g;
' "$rendered_values"

echo "[INFO] Creating or upgrading vind cluster '$CLUSTER_NAME'"
echo "[INFO] Values file template: $VALUES_FILE"
echo "[INFO] Rendered values file: $rendered_values"
echo "[INFO] vCluster Platform version: $VCP_VERSION"
echo "[INFO] Control plane nodes: $CONTROL_PLANE_NODE_COUNT"
echo "[INFO] Worker nodes: $WORKER_NODE_COUNT"
echo "[INFO] vCluster Platform host: $VCP_HOST"
echo "[INFO] Forgejo host: $FORGEJO_HOST"
echo "[INFO] Forgejo admin user: $FORGEJO_ADMIN_USER"
echo "[INFO] Sleep time zone: $SLEEP_TIME_ZONE"

vcluster create "$CLUSTER_NAME" --driver docker --upgrade --add=false --values "$rendered_values"

echo "[INFO] Annotating cluster/loft-cluster"
for _ in $(seq 1 60); do
  if kubectl get clusters.management.loft.sh loft-cluster >/dev/null 2>&1; then
    kubectl annotate --overwrite clusters.management.loft.sh loft-cluster \
      "domainPrefix=${vcp_domain_prefix}" \
      "domain=${vcp_domain}" \
      "sleepTimeZone=${SLEEP_TIME_ZONE}" >/dev/null
    break
  fi
  sleep 2
done

if ! kubectl get clusters.management.loft.sh loft-cluster >/dev/null 2>&1; then
  echo "[WARN] Could not find cluster/loft-cluster to annotate yet." >&2
fi

echo "[INFO] Applying a NoSchedule taint to the control plane node"
if kubectl wait --for=condition=Ready nodes --all --timeout=180s >/dev/null 2>&1; then
  control_plane_node="$(
    kubectl get nodes -l node-role.kubernetes.io/control-plane \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
  )"
  if [[ -z "$control_plane_node" ]]; then
    control_plane_node="$(
      kubectl get nodes -l node-role.kubernetes.io/master \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
    )"
  fi
  if [[ -z "$control_plane_node" ]] && kubectl get node "$CLUSTER_NAME" >/dev/null 2>&1; then
    control_plane_node="$CLUSTER_NAME"
  fi

  if [[ -n "$control_plane_node" ]]; then
    kubectl taint nodes "$control_plane_node" \
      node-role.kubernetes.io/control-plane=:NoSchedule \
      --overwrite >/dev/null
  else
    echo "[WARN] Could not find a control plane node to taint." >&2
  fi
else
  echo "[WARN] Timed out waiting for nodes to become ready before tainting the control plane node." >&2
fi

argocd_password=""
echo "[INFO] Looking up the Argo CD initial admin password"
for _ in $(seq 1 60); do
  secret_b64="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null || true)"
  if [[ -n "$secret_b64" ]]; then
    argocd_password="$(printf '%s' "$secret_b64" | perl -MMIME::Base64 -ne 'print decode_base64($_)')"
    break
  fi
  sleep 2
done

if [[ -z "$argocd_password" ]]; then
  echo "[WARN] Could not read argocd-initial-admin-secret yet." >&2
fi

if [[ "$SKIP_ORBSTACK_DOMAINS" != "true" ]]; then
  if ! bash vind-demo-cluster/start-orbstack-domains.sh \
    --cluster-name "$CLUSTER_NAME" \
    --vcp-host "$VCP_HOST" \
    --argocd-host "$ARGOCD_HOST" \
    --forgejo-host "$FORGEJO_HOST" \
    --env-file "$ORBSTACK_ENV_FILE"; then
    echo "[WARN] Automatic OrbStack domain setup failed." >&2
    echo "[WARN] You can rerun vind-demo-cluster/start-orbstack-domains.sh after the services are ready." >&2
  fi
fi

if [[ "$SKIP_SUMMARY" == "true" ]]; then
  exit 0
fi

cat <<EOF

[INFO] vind cluster '$CLUSTER_NAME' is ready.

The OrbStack container domain for the vind control plane will usually look like:
  https://vcluster.cp.${CLUSTER_NAME}.orb.local

That OrbStack domain is the control plane container endpoint, not the friendly
UI hostname for Argo CD or vCluster Platform.

Recommended next steps:
1. Confirm Argo CD and vCluster Platform are healthy:
   kubectl -n argocd get pods
   kubectl -n vcluster-platform get pods
2. Start vind-demo-cluster/orbstack-domains if you want friendly desktop browser hostnames:
   - https://$VCP_HOST
   - https://$ARGOCD_HOST
   - https://$FORGEJO_HOST
   - Docker network: vcluster.$CLUSTER_NAME
   - Env file: $ORBSTACK_ENV_FILE
   This is started automatically unless --skip-orbstack-domains was used.
3. Argo CD login:
   - username: admin
   - password: ${argocd_password:-<not available yet>}
4. Configure 1Password + ESO:
   - vind-demo-cluster/eso-cluster-store.yaml
   - vind-demo-cluster/bootstrap-external-secrets.yaml

EOF

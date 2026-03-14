#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Create or upgrade the local vind cluster for this repo.

This helper renders vind-demo-cluster/vcluster.yaml with the required
vCluster Platform install settings, then runs:

  vcluster create <cluster-name> --driver docker --upgrade --values <rendered-values>

Usage:
  LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/install-vind.sh

  bash vind-demo-cluster/install-vind.sh \
    --license-token "$TOKEN" \
    --vcp-version 4.7.1 \
    --vcp-host vcp.local

Options:
  --cluster-name NAME    Optional. Defaults to vcp.
  --values-file PATH     Optional. Defaults to vind-demo-cluster/vcluster.yaml.
  --license-token TOKEN  Required unless LICENSE_TOKEN is already exported.
  --vcp-version VERSION  Optional. Defaults to 4.7.1.
  --vcp-host HOST        Optional. Defaults to vcp.local.
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
VCP_HOST="${VCP_HOST:-vcp.local}"

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
    --vcp-host)
      VCP_HOST="${2:-}"
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

require_cmd vcluster
require_cmd perl
require_cmd mktemp

if [[ -z "$LICENSE_TOKEN" ]]; then
  echo "[ERROR] A vCluster Platform license token is required." >&2
  echo "[ERROR] Provide it with --license-token or export LICENSE_TOKEN." >&2
  exit 1
fi

rendered_values="$(mktemp "${TMPDIR:-/tmp}/vind-values.XXXXXX.yaml")"
cleanup() {
  rm -f "$rendered_values"
}
trap cleanup EXIT

cp "$VALUES_FILE" "$rendered_values"

export LICENSE_TOKEN VCP_VERSION VCP_HOST
perl -0pi -e '
  s/__VCP_LICENSE_TOKEN__/$ENV{LICENSE_TOKEN}/g;
  s/__VCP_PLATFORM_VERSION__/$ENV{VCP_VERSION}/g;
  s/__VCP_LOFT_HOST__/$ENV{VCP_HOST}/g;
' "$rendered_values"

echo "[INFO] Creating or upgrading vind cluster '$CLUSTER_NAME'"
echo "[INFO] Values file template: $VALUES_FILE"
echo "[INFO] Rendered values file: $rendered_values"
echo "[INFO] vCluster Platform version: $VCP_VERSION"
echo "[INFO] vCluster Platform host: $VCP_HOST"

vcluster create "$CLUSTER_NAME" --driver docker --upgrade --values "$rendered_values"

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
2. Use vind-demo-cluster/orbstack-domains for friendly hostnames such as:
   - https://$VCP_HOST
   - https://argocd.$VCP_HOST
   - https://forgejo.$VCP_HOST
   - Docker network: vcluster.$CLUSTER_NAME
3. Configure 1Password + ESO:
   - vind-demo-cluster/eso-cluster-store.yaml
   - vind-demo-cluster/bootstrap-external-secrets.yaml

EOF

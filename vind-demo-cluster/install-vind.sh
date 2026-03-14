#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${1:-vcp}"
VALUES_FILE="${2:-vind-demo-cluster/vcluster.yaml}"

if ! command -v vcluster >/dev/null 2>&1; then
  echo "[ERROR] vcluster CLI is required." >&2
  exit 1
fi

echo "[INFO] Creating or upgrading vind cluster '$CLUSTER_NAME'"
echo "[INFO] Values file: $VALUES_FILE"

vcluster create "$CLUSTER_NAME" --driver docker --upgrade --values "$VALUES_FILE"

cat <<EOF

[INFO] vind cluster '$CLUSTER_NAME' is ready.

The OrbStack container domain for the vind control plane will usually look like:
  https://vcluster.cp.${CLUSTER_NAME}.orb.local

That OrbStack domain is the control plane container endpoint, not the friendly
UI hostname for Argo CD or vCluster Platform.

Recommended next steps:
1. Install vCluster Platform into the vind cluster.
2. Use vind-demo-cluster/orbstack-domains for friendly hostnames such as:
   - https://vcp.local
   - https://argocd.vcp.local
   - https://forgejo.vcp.local
3. If you are running multiple vind environments, override the hosts in:
   vind-demo-cluster/orbstack-domains/.env

EOF

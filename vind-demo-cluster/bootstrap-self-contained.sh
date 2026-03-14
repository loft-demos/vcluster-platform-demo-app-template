#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Experimental comprehensive bootstrap helper for the self-contained vind path.

This script intentionally complements, not replaces, the step-by-step path.
Use the step-by-step docs first if you want minimal troubleshooting.

What this script can do:
1. create or upgrade a vind cluster
2. install vCluster Platform as part of that vind bootstrap
3. run local placeholder replacement for this repo
4. write the OrbStack local-domain .env file
5. optionally bootstrap the repo into Forgejo

What it does not do yet:
- configure 1Password / ESO secrets automatically
- enable Forgejo inside vind automatically

Usage:
  LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
    --repo-name my-demo-app \
    --org-name loft-demos

Optional Forgejo bootstrap:
  --forgejo-url https://forgejo.vcp.local
  --forgejo-username demo-admin
  --forgejo-token "$FORGEJO_TOKEN"
  --forgejo-owner loft-demos

Optional OrbStack local domain overrides:
  --vcp-host team-a.vcp.local
  --argocd-host argocd.team-a.vcp.local
  --forgejo-host forgejo.team-a.vcp.local
  --vcp-version 4.7.1
  --vcp-upstream something.lb.vcluster-platform.vcluster-platform.orb.local:443
  --argocd-upstream something.lb.argocd-server.argocd.orb.local:443
  --forgejo-upstream 127.0.0.1:3000
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
REPO_NAME=""
ORG_NAME=""
BASE_DOMAIN=""
VCLUSTER_NAME=""
INCLUDE_MD="true"
SKIP_VIND="false"
SKIP_REPLACE="false"
SKIP_ORBSTACK_ENV="false"
SKIP_FORGEJO="false"

VCP_HOST="vcp.local"
ARGOCD_HOST="argocd.vcp.local"
FORGEJO_HOST="forgejo.vcp.local"
VCP_UPSTREAM="127.0.0.1:8443"
ARGOCD_UPSTREAM="127.0.0.1:8080"
FORGEJO_UPSTREAM="127.0.0.1:3000"
ORBSTACK_ENV_FILE="vind-demo-cluster/orbstack-domains/.env"

LICENSE_TOKEN="${LICENSE_TOKEN:-}"
VCP_VERSION="${VCP_VERSION:-4.7.1}"
FORGEJO_URL=""
FORGEJO_USERNAME=""
FORGEJO_TOKEN="${FORGEJO_TOKEN:-}"
FORGEJO_OWNER=""
FORGEJO_OWNER_TYPE="org"

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
    --repo-name)
      REPO_NAME="${2:-}"
      shift 2
      ;;
    --org-name)
      ORG_NAME="${2:-}"
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
    --orbstack-env-file)
      ORBSTACK_ENV_FILE="${2:-}"
      shift 2
      ;;
    --forgejo-url)
      FORGEJO_URL="${2:-}"
      shift 2
      ;;
    --forgejo-username)
      FORGEJO_USERNAME="${2:-}"
      shift 2
      ;;
    --forgejo-token)
      FORGEJO_TOKEN="${2:-}"
      shift 2
      ;;
    --forgejo-owner)
      FORGEJO_OWNER="${2:-}"
      shift 2
      ;;
    --forgejo-owner-type)
      FORGEJO_OWNER_TYPE="${2:-}"
      shift 2
      ;;
    --skip-vind)
      SKIP_VIND="true"
      shift
      ;;
    --skip-replace)
      SKIP_REPLACE="true"
      shift
      ;;
    --skip-orbstack-env)
      SKIP_ORBSTACK_ENV="true"
      shift
      ;;
    --skip-forgejo)
      SKIP_FORGEJO="true"
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

require_cmd bash

if [[ "$SKIP_VIND" != "true" && -z "$LICENSE_TOKEN" ]]; then
  echo "[ERROR] --license-token or LICENSE_TOKEN is required unless --skip-vind is used." >&2
  exit 1
fi

if [[ "$SKIP_REPLACE" != "true" ]]; then
  if [[ -z "$REPO_NAME" || -z "$ORG_NAME" ]]; then
    echo "[ERROR] --repo-name and --org-name are required unless --skip-replace is used." >&2
    exit 1
  fi
fi

if [[ -z "$VCLUSTER_NAME" && -n "$REPO_NAME" ]]; then
  VCLUSTER_NAME="${REPO_NAME%-app}"
fi

if [[ -z "$BASE_DOMAIN" ]]; then
  BASE_DOMAIN="$VCP_HOST"
fi

if [[ "$SKIP_VIND" != "true" ]]; then
  bash vind-demo-cluster/install-vind.sh \
    --cluster-name "$CLUSTER_NAME" \
    --values-file "$VALUES_FILE" \
    --license-token "$LICENSE_TOKEN" \
    --vcp-version "$VCP_VERSION" \
    --vcp-host "$VCP_HOST"
fi

if [[ "$SKIP_REPLACE" != "true" ]]; then
  bash scripts/replace-text-local.sh \
    --repo-name "$REPO_NAME" \
    --org-name "$ORG_NAME" \
    --vcluster-name "$VCLUSTER_NAME" \
    --base-domain "$BASE_DOMAIN" \
    --include-md
fi

if [[ "$SKIP_ORBSTACK_ENV" != "true" ]]; then
  cat >"$ORBSTACK_ENV_FILE" <<EOF
LOCAL_BASE_DOMAIN=${VCP_HOST#*.}
VIND_DOCKER_NETWORK=vcluster.${CLUSTER_NAME}
VCP_HOST=$VCP_HOST
ARGOCD_HOST=$ARGOCD_HOST
FORGEJO_HOST=$FORGEJO_HOST
ARGOCD_UPSTREAM=$ARGOCD_UPSTREAM
VCP_UPSTREAM=$VCP_UPSTREAM
FORGEJO_UPSTREAM=$FORGEJO_UPSTREAM
EOF
  echo "[INFO] Wrote $ORBSTACK_ENV_FILE"
fi

if [[ "$SKIP_FORGEJO" != "true" ]]; then
  if [[ -n "$FORGEJO_URL" && -n "$FORGEJO_USERNAME" && -n "$FORGEJO_TOKEN" && -n "$FORGEJO_OWNER" && -n "$REPO_NAME" ]]; then
    bash scripts/bootstrap-forgejo-repo.sh \
      --forgejo-url "$FORGEJO_URL" \
      --username "$FORGEJO_USERNAME" \
      --token "$FORGEJO_TOKEN" \
      --owner "$FORGEJO_OWNER" \
      --owner-type "$FORGEJO_OWNER_TYPE" \
      --repo "$REPO_NAME"
  else
    echo "[INFO] Skipping Forgejo bootstrap because Forgejo options were not fully provided."
  fi
fi

cat <<EOF

[INFO] Self-contained bootstrap helper complete.

Recommended next steps:
1. Configure 1Password + ESO:
   - vind-demo-cluster/eso-cluster-store.yaml
   - vind-demo-cluster/bootstrap-external-secrets.yaml
2. Start the OrbStack local-domain adapter:
   cd vind-demo-cluster/orbstack-domains && docker compose up -d
3. Continue with the step-by-step vind docs for validation.

EOF

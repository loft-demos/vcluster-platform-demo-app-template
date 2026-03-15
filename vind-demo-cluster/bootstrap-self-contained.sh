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
4. start the OrbStack local-domain adapter automatically
5. bootstrap the repo into Forgejo by default

What it does not do yet:
- configure 1Password / ESO secrets automatically
- enable Forgejo inside vind automatically

Usage:
  LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
    --repo-name my-demo-app \
    --org-name loft-demos

Default Forgejo bootstrap:
  --forgejo-url https://forgejo.vcp.local
  --forgejo-username demo-admin
  --forgejo-password "$FORGEJO_ADMIN_PASSWORD"
  --forgejo-owner demo-admin

Optional OrbStack local domain overrides:
  --vcp-host team-a.vcp.local
  --argocd-host argocd.team-a.vcp.local
  --forgejo-host forgejo.team-a.vcp.local
  --vcp-version 4.7.1
  --vcp-upstream something.lb.vcluster-platform.vcluster-platform.orb.local:443
  --argocd-upstream something.lb.argocd-server.argocd.orb.local:80
  --forgejo-upstream vcluster.lb.team-a.forgejo-http.forgejo:3000
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
VCP_UPSTREAM=""
ARGOCD_UPSTREAM=""
FORGEJO_UPSTREAM=""
ORBSTACK_ENV_FILE=""

LICENSE_TOKEN="${LICENSE_TOKEN:-}"
VCP_VERSION="${VCP_VERSION:-4.7.1}"
FORGEJO_URL=""
FORGEJO_USERNAME="${FORGEJO_ADMIN_USER:-demo-admin}"
FORGEJO_TOKEN="${FORGEJO_TOKEN:-}"
FORGEJO_PASSWORD="${FORGEJO_PASSWORD:-${FORGEJO_ADMIN_PASSWORD:-vcluster-demo-admin}}"
FORGEJO_OWNER="${FORGEJO_OWNER:-}"
FORGEJO_OWNER_TYPE="user"

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
    --forgejo-password)
      FORGEJO_PASSWORD="${2:-}"
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

if [[ -z "$ORBSTACK_ENV_FILE" ]]; then
  if [[ "$CLUSTER_NAME" == "vcp" ]]; then
    ORBSTACK_ENV_FILE="vind-demo-cluster/orbstack-domains/.env"
  else
    ORBSTACK_ENV_FILE="vind-demo-cluster/orbstack-domains/.env.${CLUSTER_NAME}"
  fi
fi

if [[ -z "$FORGEJO_URL" ]]; then
  FORGEJO_URL="https://${FORGEJO_HOST}"
fi

if [[ -z "$FORGEJO_OWNER" ]]; then
  FORGEJO_OWNER="$FORGEJO_USERNAME"
fi

if [[ "$SKIP_VIND" != "true" ]]; then
  bash vind-demo-cluster/install-vind.sh \
    --cluster-name "$CLUSTER_NAME" \
    --values-file "$VALUES_FILE" \
    --license-token "$LICENSE_TOKEN" \
    --vcp-version "$VCP_VERSION" \
    --vcp-host "$VCP_HOST" \
    --argocd-host "$ARGOCD_HOST" \
    --forgejo-host "$FORGEJO_HOST" \
    --forgejo-admin-user "$FORGEJO_USERNAME" \
    --forgejo-admin-password "$FORGEJO_PASSWORD" \
    --orbstack-env-file "$ORBSTACK_ENV_FILE" \
    --skip-orbstack-domains
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
  bash vind-demo-cluster/start-orbstack-domains.sh \
    --cluster-name "$CLUSTER_NAME" \
    --vcp-host "$VCP_HOST" \
    --argocd-host "$ARGOCD_HOST" \
    --forgejo-host "$FORGEJO_HOST" \
    --vcp-upstream "$VCP_UPSTREAM" \
    --argocd-upstream "$ARGOCD_UPSTREAM" \
    --forgejo-upstream "$FORGEJO_UPSTREAM" \
    --env-file "$ORBSTACK_ENV_FILE"
fi

if [[ "$SKIP_FORGEJO" != "true" ]]; then
  if [[ -n "$REPO_NAME" ]]; then
    declare -a forgejo_auth_args
    require_cmd curl
    for _ in $(seq 1 60); do
      if curl -ksSf "${FORGEJO_URL}/api/healthz" >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done

    if [[ -n "$FORGEJO_TOKEN" ]]; then
      forgejo_auth_args+=(--token "$FORGEJO_TOKEN")
    elif [[ -n "$FORGEJO_PASSWORD" ]]; then
      forgejo_auth_args+=(--password "$FORGEJO_PASSWORD")
    fi

    bash scripts/bootstrap-forgejo-repo.sh \
      --forgejo-url "$FORGEJO_URL" \
      --username "$FORGEJO_USERNAME" \
      "${forgejo_auth_args[@]}" \
      --owner "$FORGEJO_OWNER" \
      --owner-type "$FORGEJO_OWNER_TYPE" \
      --repo "$REPO_NAME"
  else
    echo "[INFO] Skipping Forgejo bootstrap because --repo-name was not provided."
  fi
fi

cat <<EOF

[INFO] Self-contained bootstrap helper complete.

Recommended next steps:
1. Configure 1Password + ESO:
   - vind-demo-cluster/eso-cluster-store.yaml
   - vind-demo-cluster/bootstrap-external-secrets.yaml
2. Continue with the step-by-step vind docs for validation.

EOF

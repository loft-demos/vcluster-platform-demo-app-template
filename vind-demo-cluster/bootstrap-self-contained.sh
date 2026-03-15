#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Default comprehensive bootstrap helper for the self-contained vind path.

What this script can do:
1. create or upgrade a vind cluster
2. install vCluster Platform as part of that vind bootstrap
3. run local placeholder replacement for this repo
4. start the OrbStack local-domain adapter automatically
5. bootstrap the repo into Forgejo by default
6. build and push the demo app image to the Forgejo container registry
7. create the Argo CD Forgejo secrets, the default vCP ProjectSecret, and apply the self-contained root app

What it does not do yet:
- configure 1Password / ESO secrets automatically

Usage:
  LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
    --repo-name vcp-gitops \
    --org-name vcluster-demos

Default Forgejo bootstrap:
  --forgejo-url https://forgejo.vcp.local
  --forgejo-username demo-admin
  --forgejo-password "$FORGEJO_ADMIN_PASSWORD"
  --forgejo-owner vcluster-demos

Optional OrbStack local domain overrides:
  --vcp-host team-a.vcp.local
  --argocd-host argocd.team-a.vcp.local
  --forgejo-host forgejo.team-a.vcp.local
  --vcp-version 4.7.1
  --worker-nodes 2
  --sleep-time-zone America/New_York
  --vcp-upstream vcluster.lb.team-a.loft.vcluster-platform:443
  --argocd-upstream vcluster.lb.team-a.argocd-server.argocd:443
  --forgejo-upstream vcluster.lb.team-a.forgejo-http.forgejo:3000

Optional skip flags:
  --skip-vind
  --skip-replace
  --skip-orbstack-env
  --skip-forgejo
  --skip-image-build
  --skip-argocd-bootstrap

ProjectSecret defaults:
  --image-pull-project-namespace p-default
  --image-pull-project-secret-name vcluster-demos-ghcr-write-pat
  --image-pull-source-secret-name vcluster-demos-ghcr-write
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
REPO_NAME="vcp-gitops"
ORG_NAME="vcluster-demos"
BASE_DOMAIN=""
VCLUSTER_NAME=""
INCLUDE_MD="true"
SKIP_VIND="false"
SKIP_REPLACE="false"
SKIP_ORBSTACK_ENV="false"
SKIP_FORGEJO="false"
SKIP_IMAGE_BUILD="false"

VCP_HOST="vcp.local"
ARGOCD_HOST="argocd.vcp.local"
FORGEJO_HOST="forgejo.vcp.local"
VCP_UPSTREAM=""
ARGOCD_UPSTREAM=""
FORGEJO_UPSTREAM=""
ORBSTACK_ENV_FILE=""

LICENSE_TOKEN="${LICENSE_TOKEN:-}"
VCP_VERSION="${VCP_VERSION:-4.7.1}"
CONTROL_PLANE_NODE_COUNT="${CONTROL_PLANE_NODE_COUNT:-1}"
WORKER_NODE_COUNT="${WORKER_NODE_COUNT:-2}"
SLEEP_TIME_ZONE="${SLEEP_TIME_ZONE:-America/New_York}"
FORGEJO_URL=""
FORGEJO_USERNAME="${FORGEJO_ADMIN_USER:-demo-admin}"
FORGEJO_TOKEN="${FORGEJO_TOKEN:-}"
FORGEJO_PASSWORD="${FORGEJO_PASSWORD:-${FORGEJO_ADMIN_PASSWORD:-vcluster-demo-admin}}"
FORGEJO_OWNER="${FORGEJO_OWNER:-}"
FORGEJO_OWNER_TYPE="${FORGEJO_OWNER_TYPE:-}"
GIT_BASE_URL=""
GIT_PUBLIC_URL=""
IMAGE_REPOSITORY_PREFIX=""
SKIP_ARGOCD_BOOTSTRAP="false"
IMAGE_PULL_PROJECT_NAMESPACE="p-default"
IMAGE_PULL_PROJECT_SECRET_NAME=""
IMAGE_PULL_SOURCE_SECRET_NAME=""

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
    --control-plane-nodes)
      CONTROL_PLANE_NODE_COUNT="${2:-}"
      shift 2
      ;;
    --worker-nodes)
      WORKER_NODE_COUNT="${2:-}"
      shift 2
      ;;
    --sleep-time-zone)
      SLEEP_TIME_ZONE="${2:-}"
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
    --git-base-url)
      GIT_BASE_URL="${2:-}"
      shift 2
      ;;
    --git-public-url)
      GIT_PUBLIC_URL="${2:-}"
      shift 2
      ;;
    --image-repository-prefix)
      IMAGE_REPOSITORY_PREFIX="${2:-}"
      shift 2
      ;;
    --image-pull-project-namespace)
      IMAGE_PULL_PROJECT_NAMESPACE="${2:-}"
      shift 2
      ;;
    --image-pull-project-secret-name)
      IMAGE_PULL_PROJECT_SECRET_NAME="${2:-}"
      shift 2
      ;;
    --image-pull-source-secret-name)
      IMAGE_PULL_SOURCE_SECRET_NAME="${2:-}"
      shift 2
      ;;
    --skip-image-build)
      SKIP_IMAGE_BUILD="true"
      shift
      ;;
    --skip-argocd-bootstrap)
      SKIP_ARGOCD_BOOTSTRAP="true"
      shift
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

if [[ ! "$CONTROL_PLANE_NODE_COUNT" =~ ^[0-9]+$ || "$CONTROL_PLANE_NODE_COUNT" -ne 1 ]]; then
  echo "[ERROR] --control-plane-nodes must be 1 for this vind configuration." >&2
  exit 1
fi

if [[ ! "$WORKER_NODE_COUNT" =~ ^[0-9]+$ ]]; then
  echo "[ERROR] --worker-nodes must be a non-negative integer." >&2
  exit 1
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
  if [[ -n "$ORG_NAME" ]]; then
    FORGEJO_OWNER="$ORG_NAME"
  else
    FORGEJO_OWNER="$FORGEJO_USERNAME"
  fi
fi

if [[ -z "$FORGEJO_OWNER_TYPE" ]]; then
  if [[ "$FORGEJO_OWNER" == "$FORGEJO_USERNAME" ]]; then
    FORGEJO_OWNER_TYPE="user"
  else
    FORGEJO_OWNER_TYPE="org"
  fi
fi

if [[ -z "$GIT_BASE_URL" ]]; then
  GIT_BASE_URL="http://forgejo-http.forgejo.svc.cluster.local:3000"
fi

if [[ -z "$GIT_PUBLIC_URL" ]]; then
  GIT_PUBLIC_URL="${FORGEJO_URL%/}"
fi

if [[ -z "$IMAGE_REPOSITORY_PREFIX" ]]; then
  IMAGE_REPOSITORY_PREFIX="${FORGEJO_HOST}/${FORGEJO_OWNER}"
fi

if [[ -z "$IMAGE_PULL_PROJECT_SECRET_NAME" ]]; then
  IMAGE_PULL_PROJECT_SECRET_NAME="${ORG_NAME}-ghcr-write-pat"
fi

if [[ -z "$IMAGE_PULL_SOURCE_SECRET_NAME" ]]; then
  IMAGE_PULL_SOURCE_SECRET_NAME="${ORG_NAME}-ghcr-write"
fi

if [[ "$SKIP_VIND" != "true" ]]; then
  bash vind-demo-cluster/install-vind.sh \
    --cluster-name "$CLUSTER_NAME" \
    --values-file "$VALUES_FILE" \
    --license-token "$LICENSE_TOKEN" \
    --vcp-version "$VCP_VERSION" \
    --control-plane-nodes "$CONTROL_PLANE_NODE_COUNT" \
    --worker-nodes "$WORKER_NODE_COUNT" \
    --sleep-time-zone "$SLEEP_TIME_ZONE" \
    --vcp-host "$VCP_HOST" \
    --argocd-host "$ARGOCD_HOST" \
    --forgejo-host "$FORGEJO_HOST" \
    --forgejo-admin-user "$FORGEJO_USERNAME" \
    --forgejo-admin-password "$FORGEJO_PASSWORD" \
    --orbstack-env-file "$ORBSTACK_ENV_FILE" \
    --skip-orbstack-domains \
    --skip-summary
fi

if [[ "$SKIP_REPLACE" != "true" ]]; then
  bash scripts/replace-text-local.sh \
    --repo-name "$REPO_NAME" \
    --org-name "$ORG_NAME" \
    --vcluster-name "$VCLUSTER_NAME" \
    --base-domain "$BASE_DOMAIN" \
    --git-base-url "$GIT_BASE_URL" \
    --git-public-url "$GIT_PUBLIC_URL" \
    --image-repository-prefix "$IMAGE_REPOSITORY_PREFIX" \
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
      --repo "$REPO_NAME" \
      --include-working-tree
  else
    echo "[INFO] Skipping Forgejo bootstrap because --repo-name was not provided."
  fi
fi

if [[ "$SKIP_IMAGE_BUILD" != "true" ]]; then
  require_cmd docker

  image_auth_password="$FORGEJO_PASSWORD"
  image_auth_token="$FORGEJO_TOKEN"
  declare -a image_auth_args

  if [[ -n "$image_auth_token" ]]; then
    image_auth_args+=(--token "$image_auth_token")
  elif [[ -n "$image_auth_password" ]]; then
    image_auth_args+=(--password "$image_auth_password")
  fi

  bash scripts/build-push-forgejo-image.sh \
    --registry "$FORGEJO_HOST" \
    --image-repository-prefix "$IMAGE_REPOSITORY_PREFIX" \
    --repo-name "$REPO_NAME" \
    --username "$FORGEJO_USERNAME" \
    "${image_auth_args[@]}" \
    --source-url "${GIT_PUBLIC_URL%/}/${ORG_NAME}/${REPO_NAME}"
fi

if [[ "$SKIP_ARGOCD_BOOTSTRAP" != "true" ]]; then
  require_cmd kubectl
  require_cmd jq
  require_cmd curl

  if [[ -z "$REPO_NAME" || -z "$ORG_NAME" ]]; then
    echo "[WARN] Skipping Argo CD bootstrap because --repo-name and --org-name were not provided." >&2
  else
    kubectl -n argocd wait --for=condition=Available deploy/argocd-server --timeout=300s >/dev/null 2>&1 || true
    kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=180s >/dev/null 2>&1 || true

    argocd_token="${FORGEJO_TOKEN:-}"

    if [[ -z "$argocd_token" ]]; then
      token_name="argocd-bootstrap-$(date +%s)"
      token_payload="$(jq -cn --arg name "$token_name" '{name: $name, scopes: ["all"]}')"
      argocd_token="$(
        curl -fsS \
          -u "${FORGEJO_USERNAME}:${FORGEJO_PASSWORD}" \
          -H "Content-Type: application/json" \
          -X POST \
          "${FORGEJO_URL%/}/api/v1/users/${FORGEJO_USERNAME}/tokens" \
          -d "$token_payload" | jq -r '.sha1'
      )"
    fi

    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: forgejo-repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: ${GIT_BASE_URL}/${ORG_NAME}
  username: ${FORGEJO_USERNAME}
  password: ${argocd_token}
---
apiVersion: v1
kind: Secret
metadata:
  name: loft-demo-org-cred
  namespace: argocd
stringData:
  token: ${argocd_token}
EOF

    kubectl apply -f vcluster-gitops/overlays/local-contained/root-application.yaml
  fi
fi

if command -v kubectl >/dev/null 2>&1; then
  project_secret_password="${FORGEJO_TOKEN:-}"
  if [[ -z "$project_secret_password" && -n "${argocd_token:-}" ]]; then
    project_secret_password="$argocd_token"
  fi
  if [[ -z "$project_secret_password" ]]; then
    project_secret_password="$FORGEJO_PASSWORD"
  fi

  if [[ -n "$project_secret_password" ]]; then
    for _ in $(seq 1 60); do
      if kubectl get namespace "$IMAGE_PULL_PROJECT_NAMESPACE" >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done

    if kubectl get namespace "$IMAGE_PULL_PROJECT_NAMESPACE" >/dev/null 2>&1; then
      cat <<EOF | kubectl apply -f -
apiVersion: management.loft.sh/v1
kind: ProjectSecret
metadata:
  name: ${IMAGE_PULL_PROJECT_SECRET_NAME}
  namespace: ${IMAGE_PULL_PROJECT_NAMESPACE}
  labels:
    loft.sh/project-secret-name: ${IMAGE_PULL_SOURCE_SECRET_NAME}
    org: ${ORG_NAME}
    repo: ${REPO_NAME}
spec:
  displayName: ${IMAGE_PULL_PROJECT_SECRET_NAME}
  data:
    username: ${FORGEJO_USERNAME}
    password: ${project_secret_password}
EOF
    else
      echo "[WARN] Could not find namespace ${IMAGE_PULL_PROJECT_NAMESPACE} to create ${IMAGE_PULL_PROJECT_SECRET_NAME}." >&2
    fi
  fi
fi

argocd_password=""
if command -v kubectl >/dev/null 2>&1; then
  echo "[INFO] Looking up the Argo CD initial admin password"
  for _ in $(seq 1 60); do
    secret_b64="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null || true)"
    if [[ -n "$secret_b64" ]]; then
      argocd_password="$(printf '%s' "$secret_b64" | perl -MMIME::Base64 -ne 'print decode_base64($_)')"
      break
    fi
    sleep 2
  done
fi

cat <<EOF

[INFO] Self-contained bootstrap helper complete.

Recommended next steps:
1. Argo CD login:
   - username: admin
   - password: ${argocd_password:-<not available yet>}
2. Open the local URLs:
   - https://${VCP_HOST}
   - https://${ARGOCD_HOST}
   - https://${FORGEJO_HOST}
3. Configure 1Password + ESO:
   - vind-demo-cluster/eso-cluster-store.yaml
   - vind-demo-cluster/bootstrap-external-secrets.yaml
4. Confirm Argo CD and vCluster Platform are healthy:
   - kubectl -n argocd get pods
   - kubectl -n vcluster-platform get pods
5. Continue with vind-demo-cluster/README.md if you want the detailed flow.

EOF

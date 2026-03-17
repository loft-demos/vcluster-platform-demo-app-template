#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./use-case-labels.sh
source "$(dirname "$0")/use-case-labels.sh"

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
  --onepassword-vault team-a
  --vcp-version 4.8.0
  --worker-nodes 2
  --use-cases eso,auto-snapshots
  --private-node-vm-name private-node-demo-worker-1
  --sleep-time-zone America/New_York
  --vcp-upstream vcluster.lb.team-a.loft.vcluster-platform:443
  --argocd-upstream vcluster.lb.team-a.argocd-server.argocd:443
  --forgejo-upstream vcluster.lb.team-a.forgejo-http.forgejo:3000
  --image-platform linux/arm64

Optional skip flags:
  --skip-vind
  --skip-replace
  --skip-orbstack-env
  --skip-forgejo
  --skip-image-build
  --wait-for-image-build
  --skip-argocd-bootstrap

ProjectSecret defaults:
  --image-pull-project-namespace p-default
  --image-pull-project-secret-name vcluster-demos-ghcr-write-pat
  --image-pull-source-secret-name vcluster-demos-ghcr-write
  --snapshot-registry-username <ghcr-user>
  --snapshot-registry-token <ghcr-token>

Use case selection:
  --use-cases default
  --use-cases eso,auto-snapshots,flux
  --use-cases all,-crossplane,-rancher
  --list-use-cases
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd" >&2
    exit 1
  fi
}

step() {
  STEP_INDEX=$((STEP_INDEX + 1))
  echo
  echo "[STEP ${STEP_INDEX}/${TOTAL_STEPS}] $1"
}

annotate_loft_cluster() {
  local domain_prefix="$1"
  local domain_name="$2"
  local sleep_time_zone="$3"
  local cluster_annotated="false"

  echo "[INFO] Waiting for vCluster Platform deployment to become available"
  for attempt in $(seq 1 30); do
    if kubectl -n vcluster-platform wait --for=condition=Available deploy/loft --timeout=10s >/dev/null 2>&1; then
      echo "[INFO] vCluster Platform deployment is available"
      break
    fi
    if (( attempt % 3 == 0 )); then
      echo "[INFO] Still waiting for deploy/loft (${attempt}/30)"
      kubectl get deploy,pods -n vcluster-platform --no-headers 2>/dev/null || true
    fi
  done

  echo "[INFO] Waiting for clusters.management.loft.sh/loft-cluster"
  for attempt in $(seq 1 60); do
    if kubectl get clusters.management.loft.sh loft-cluster >/dev/null 2>&1; then
      kubectl annotate --overwrite clusters.management.loft.sh loft-cluster \
        "domainPrefix=${domain_prefix}" \
        "domain=${domain_name}" \
        "sleepTimeZone=${sleep_time_zone}" >/dev/null
      cluster_annotated="true"
      break
    fi
    if (( attempt % 5 == 0 )); then
      echo "[INFO] Still waiting for cluster/loft-cluster (${attempt}/60)"
    fi
    sleep 2
  done

  if [[ "$cluster_annotated" == "true" ]]; then
    echo "[INFO] Annotated cluster/loft-cluster"
  else
    echo "[WARN] Could not find cluster/loft-cluster to annotate yet." >&2
  fi
}

taint_control_plane_node() {
  local cluster_name="$1"
  local control_plane_node=""

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
    if [[ -z "$control_plane_node" ]] && kubectl get node "$cluster_name" >/dev/null 2>&1; then
      control_plane_node="$cluster_name"
    fi

    if [[ -n "$control_plane_node" ]]; then
      kubectl taint nodes "$control_plane_node" \
        node-role.kubernetes.io/control-plane=:NoSchedule \
        --overwrite >/dev/null
      echo "[INFO] Applied NoSchedule taint to node ${control_plane_node}"
    else
      echo "[WARN] Could not find a control plane node to taint." >&2
    fi
  else
    echo "[WARN] Timed out waiting for nodes to become ready before tainting the control plane node." >&2
  fi
}

apply_cluster_local_secret() {
  local vcp_host="$1"
  local domain_prefix="$2"
  local domain_name="$3"
  local use_case_spec="$4"
  local labels_block=""

  labels_block="$(render_cluster_local_use_case_labels "$use_case_spec" '    ')" || return 1

  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: cluster-local
  namespace: argocd
  annotations:
    domainPrefix: ${domain_prefix}
    domain: ${domain_name}
  labels:
    argocd.argoproj.io/secret-type: cluster
    loftDemoDomain: ${vcp_host}
    domainPrefix: ${domain_prefix}
    domain: ${domain_name}
${labels_block}
type: Opaque
stringData:
  config: '{"tlsClientConfig":{"insecure":false}}'
  name: in-cluster
  server: https://kubernetes.default.svc
EOF
}

current_cluster_local_use_cases() {
  local selected=""
  local use_case=""
  local label_key=""
  local label_value=""

  command -v kubectl >/dev/null 2>&1 || return 1
  kubectl -n argocd get secret cluster-local >/dev/null 2>&1 || return 1

  while IFS='|' read -r use_case label_key; do
    [[ -z "$use_case" || -z "$label_key" ]] && continue
    label_value="$(
      kubectl -n argocd get secret cluster-local \
        -o "jsonpath={.metadata.labels.${label_key}}" 2>/dev/null || true
    )"
    if [[ "$label_value" == "true" ]]; then
      if [[ -z "$selected" ]]; then
        selected="$use_case"
      else
        selected="${selected},${use_case}"
      fi
    fi
  done <<EOF
$(known_use_case_entries)
EOF

  if [[ -n "$selected" ]]; then
    printf '%s\n' "$selected"
    return 0
  fi

  return 1
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
WAIT_FOR_IMAGE_BUILD="false"

VCP_HOST="vcp.local"
ARGOCD_HOST="argocd.vcp.local"
FORGEJO_HOST="forgejo.vcp.local"
VCP_UPSTREAM=""
ARGOCD_UPSTREAM=""
FORGEJO_UPSTREAM=""
ORBSTACK_ENV_FILE=""

LICENSE_TOKEN="${LICENSE_TOKEN:-}"
VCP_VERSION="${VCP_VERSION:-4.8.0}"
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
IMAGE_PLATFORM="auto"
USE_CASES="${USE_CASES:-$DEFAULT_USE_CASE_SPEC}"
USE_CASES_EXPLICIT="false"
SKIP_ARGOCD_BOOTSTRAP="false"
IMAGE_PULL_PROJECT_NAMESPACE="p-default"
IMAGE_PULL_PROJECT_SECRET_NAME=""
IMAGE_PULL_SOURCE_SECRET_NAME=""
ONEPASSWORD_VAULT=""
PRIVATE_NODE_VM_NAME="${PRIVATE_NODE_VM_NAME:-private-node-demo-worker-1}"
SNAPSHOT_REGISTRY_USERNAME="${SNAPSHOT_REGISTRY_USERNAME:-${GHCR_USERNAME:-}}"
SNAPSHOT_REGISTRY_TOKEN="${SNAPSHOT_REGISTRY_TOKEN:-${GHCR_TOKEN:-}}"
SNAPSHOT_REGISTRY_PASSWORD="${SNAPSHOT_REGISTRY_PASSWORD:-${GHCR_PASSWORD:-}}"

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
    --onepassword-vault)
      ONEPASSWORD_VAULT="${2:-}"
      shift 2
      ;;
    --private-node-vm-name)
      PRIVATE_NODE_VM_NAME="${2:-}"
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
    --image-platform)
      IMAGE_PLATFORM="${2:-}"
      shift 2
      ;;
    --use-cases)
      USE_CASES="${2:-}"
      USE_CASES_EXPLICIT="true"
      shift 2
      ;;
    --list-use-cases)
      print_known_use_cases
      exit 0
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
    --snapshot-registry-username)
      SNAPSHOT_REGISTRY_USERNAME="${2:-}"
      shift 2
      ;;
    --snapshot-registry-token)
      SNAPSHOT_REGISTRY_TOKEN="${2:-}"
      shift 2
      ;;
    --snapshot-registry-password)
      SNAPSHOT_REGISTRY_PASSWORD="${2:-}"
      shift 2
      ;;
    --skip-image-build)
      SKIP_IMAGE_BUILD="true"
      shift
      ;;
    --wait-for-image-build)
      WAIT_FOR_IMAGE_BUILD="true"
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
  IMAGE_REPOSITORY_PREFIX="${FORGEJO_HOST}/${FORGEJO_OWNER}/${REPO_NAME}"
fi

if [[ -z "$IMAGE_PULL_PROJECT_SECRET_NAME" ]]; then
  IMAGE_PULL_PROJECT_SECRET_NAME="${ORG_NAME}-ghcr-write-pat"
fi

if [[ -z "$IMAGE_PULL_SOURCE_SECRET_NAME" ]]; then
  IMAGE_PULL_SOURCE_SECRET_NAME="${ORG_NAME}-ghcr-write"
fi

if [[ -z "$ONEPASSWORD_VAULT" ]]; then
  ONEPASSWORD_VAULT="$ORG_NAME"
fi

if [[ "$SKIP_VIND" == "true" && "$USE_CASES_EXPLICIT" != "true" ]]; then
  existing_use_cases="$(current_cluster_local_use_cases || true)"
  if [[ -n "$existing_use_cases" ]]; then
    USE_CASES="$existing_use_cases"
  fi
fi

selected_use_cases="$(selected_use_cases_csv "$USE_CASES")"
resolved_use_case_selection="$(resolve_use_case_selection "$USE_CASES")"
PRIVATE_NODES_ENABLED="false"
if use_case_list_contains "$resolved_use_case_selection" "private-nodes"; then
  PRIVATE_NODES_ENABLED="true"
fi

vcp_domain_prefix="${VCP_HOST%%.*}"
if [[ "$VCP_HOST" == *.* ]]; then
  vcp_domain="${VCP_HOST#*.}"
else
  vcp_domain="local"
fi

TOTAL_STEPS=0
if [[ "$SKIP_VIND" != "true" ]]; then
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi
if [[ "$SKIP_REPLACE" != "true" ]]; then
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi
if [[ "$SKIP_ORBSTACK_ENV" != "true" ]]; then
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi
if [[ "$SKIP_FORGEJO" != "true" ]]; then
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi
if [[ "$SKIP_IMAGE_BUILD" != "true" ]]; then
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi
if [[ "$SKIP_ARGOCD_BOOTSTRAP" != "true" ]]; then
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi
if command -v kubectl >/dev/null 2>&1; then
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
  if [[ "$SKIP_ARGOCD_BOOTSTRAP" != "true" ]]; then
    TOTAL_STEPS=$((TOTAL_STEPS + 1))
    TOTAL_STEPS=$((TOTAL_STEPS + 1))
  fi
fi
if [[ "$PRIVATE_NODES_ENABLED" == "true" ]]; then
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi

STEP_INDEX=0
IMAGE_BUILD_LOG=""
IMAGE_BUILD_PID=""

if [[ "$SKIP_VIND" != "true" ]]; then
  step "Create or upgrade the vind cluster"
  bash vind-demo-cluster/install-vind.sh \
    --cluster-name "$CLUSTER_NAME" \
    --values-file "$VALUES_FILE" \
    --license-token "$LICENSE_TOKEN" \
    --vcp-version "$VCP_VERSION" \
    --repo-name "$REPO_NAME" \
    --org-name "$ORG_NAME" \
    --vcluster-name "$VCLUSTER_NAME" \
    --control-plane-nodes "$CONTROL_PLANE_NODE_COUNT" \
    --worker-nodes "$WORKER_NODE_COUNT" \
    --use-cases "$USE_CASES" \
    --sleep-time-zone "$SLEEP_TIME_ZONE" \
    --vcp-host "$VCP_HOST" \
    --argocd-host "$ARGOCD_HOST" \
    --forgejo-host "$FORGEJO_HOST" \
    --forgejo-admin-user "$FORGEJO_USERNAME" \
    --forgejo-admin-password "$FORGEJO_PASSWORD" \
    --orbstack-env-file "$ORBSTACK_ENV_FILE" \
    --skip-cluster-annotation \
    --skip-orbstack-domains \
    --skip-summary
fi

if [[ "$SKIP_REPLACE" != "true" ]]; then
  step "Render repo placeholders for the self-contained path"
  bash scripts/replace-text-local.sh \
    --repo-name "$REPO_NAME" \
    --org-name "$ORG_NAME" \
    --vcluster-name "$VCLUSTER_NAME" \
    --base-domain "$BASE_DOMAIN" \
    --git-base-url "$GIT_BASE_URL" \
    --git-public-url "$GIT_PUBLIC_URL" \
    --image-repository-prefix "$IMAGE_REPOSITORY_PREFIX" \
    --oci-registry-host "$FORGEJO_HOST" \
    --image-pull-source-secret-name "$IMAGE_PULL_SOURCE_SECRET_NAME" \
    --onepassword-vault "$ONEPASSWORD_VAULT" \
    --include-md
fi

if [[ "$SKIP_ORBSTACK_ENV" != "true" ]]; then
  step "Configure local OrbStack domains"
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
  step "Bootstrap the Forgejo repository"
  if [[ -n "$REPO_NAME" ]]; then
    declare -a forgejo_auth_args
    require_cmd curl
    echo "[INFO] Waiting for Forgejo API at ${FORGEJO_URL}/api/healthz"
    for attempt in $(seq 1 60); do
      if curl -ksSf "${FORGEJO_URL}/api/healthz" >/dev/null 2>&1; then
        echo "[INFO] Forgejo API is reachable"
        break
      fi
      if (( attempt % 5 == 0 )); then
        echo "[INFO] Still waiting for Forgejo API (${attempt}/60)"
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
      --current-branch-only \
      --skip-tags \
      --include-working-tree
  else
    echo "[INFO] Skipping Forgejo bootstrap because --repo-name was not provided."
  fi
fi

if [[ "$SKIP_IMAGE_BUILD" != "true" ]]; then
  if [[ "$WAIT_FOR_IMAGE_BUILD" == "true" ]]; then
    step "Build and push the demo image to Forgejo"
  else
    step "Start the demo image build in the background"
  fi
  require_cmd docker
  require_cmd nohup

  image_auth_password="$FORGEJO_PASSWORD"
  image_auth_token="$FORGEJO_TOKEN"
  declare -a image_auth_args

  if [[ -n "$image_auth_token" ]]; then
    image_auth_args+=(--token "$image_auth_token")
  elif [[ -n "$image_auth_password" ]]; then
    image_auth_args+=(--password "$image_auth_password")
  fi

  declare -a image_build_cmd
  image_build_cmd=(
    bash scripts/build-push-forgejo-image.sh
    --registry "$FORGEJO_HOST"
    --image-repository-prefix "$IMAGE_REPOSITORY_PREFIX"
    --repo-name "$REPO_NAME"
    --username "$FORGEJO_USERNAME"
    "${image_auth_args[@]}"
    --platform "$IMAGE_PLATFORM"
    --source-url "${GIT_PUBLIC_URL%/}/${ORG_NAME}/${REPO_NAME}"
    --skip-cache
  )

  if [[ "$WAIT_FOR_IMAGE_BUILD" == "true" ]]; then
    "${image_build_cmd[@]}"
  else
    mkdir -p vind-demo-cluster/logs
    IMAGE_BUILD_LOG="vind-demo-cluster/logs/image-build-${CLUSTER_NAME}-$(date +%Y%m%d-%H%M%S).log"
    nohup "${image_build_cmd[@]}" >"$IMAGE_BUILD_LOG" 2>&1 &
    IMAGE_BUILD_PID="$!"
    echo "[INFO] Image build running in background."
    echo "[INFO] PID: $IMAGE_BUILD_PID"
    echo "[INFO] Log: $IMAGE_BUILD_LOG"
  fi
fi

if [[ "$SKIP_ARGOCD_BOOTSTRAP" != "true" ]]; then
  step "Apply the control-plane NoSchedule taint"
  require_cmd kubectl
  taint_control_plane_node "$CLUSTER_NAME"

  step "Annotate cluster/loft-cluster for Platform-side host and timezone values"
  require_cmd kubectl
  annotate_loft_cluster "$vcp_domain_prefix" "$vcp_domain" "$SLEEP_TIME_ZONE"

  step "Create Argo CD credentials and apply the root application"
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
  step "Apply cluster-local use case labels"
  require_cmd kubectl
  apply_cluster_local_secret "$VCP_HOST" "$vcp_domain_prefix" "$vcp_domain" "$USE_CASES"

  step "Create the default Platform registry auth secrets"
  require_cmd base64
  require_cmd jq
  project_secret_password="${SNAPSHOT_REGISTRY_TOKEN:-$SNAPSHOT_REGISTRY_PASSWORD}"

  if [[ -n "$SNAPSHOT_REGISTRY_USERNAME" && -n "$project_secret_password" ]]; then
    for _ in $(seq 1 60); do
      if kubectl get namespace vcluster-platform >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done

    if kubectl get namespace vcluster-platform >/dev/null 2>&1; then
      for project_secret_namespace in p-api-framework p-auth-core; do
        for _ in $(seq 1 60); do
          if kubectl get namespace "$project_secret_namespace" >/dev/null 2>&1; then
            break
          fi
          sleep 2
        done
      done

      ghcr_auth_b64="$(printf '%s:%s' "$SNAPSHOT_REGISTRY_USERNAME" "$project_secret_password" | base64 | tr -d '\n')"
      ghcr_dockerconfigjson="$(
        jq -cn \
          --arg username "$SNAPSHOT_REGISTRY_USERNAME" \
          --arg password "$project_secret_password" \
          --arg auth "$ghcr_auth_b64" \
          '{auths: {"ghcr.io": {username: $username, password: $password, auth: $auth}}}'
      )"
      ghcr_dockerconfigjson_b64="$(printf '%s' "$ghcr_dockerconfigjson" | base64 | tr -d '\n')"
      if kubectl get namespace p-api-framework >/dev/null 2>&1 && kubectl get namespace p-auth-core >/dev/null 2>&1; then
        cat <<EOF | kubectl apply -f -
apiVersion: management.loft.sh/v1
kind: SharedSecret
metadata:
  name: ghcr-login-secret
  namespace: vcluster-platform
spec:
  displayName: ghcr-login-secret
  description: Pull image secret for loft-demos ghcr
  data:
    .dockerconfigjson: ${ghcr_dockerconfigjson_b64}
---
apiVersion: management.loft.sh/v1
kind: ProjectSecret
metadata:
  name: ghcr-login-secret
  namespace: p-api-framework
  labels:
    loft.sh/sharedsecret-name: ghcr-login-secret
    loft.sh/sharedsecret-namespace: vcluster-platform
spec:
  displayName: ghcr-login-secret
---
apiVersion: management.loft.sh/v1
kind: ProjectSecret
metadata:
  name: ghcr-login-secret
  namespace: p-auth-core
  labels:
    loft.sh/sharedsecret-name: ghcr-login-secret
    loft.sh/sharedsecret-namespace: vcluster-platform
spec:
  displayName: ghcr-login-secret
EOF
      else
        echo "[WARN] Could not find p-api-framework and p-auth-core to create ghcr-login-secret projections." >&2
      fi
    else
      echo "[WARN] Could not find namespace vcluster-platform to create ghcr-login-secret." >&2
    fi

    for _ in $(seq 1 60); do
      if kubectl get namespace "$IMAGE_PULL_PROJECT_NAMESPACE" >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done

    if kubectl get namespace "$IMAGE_PULL_PROJECT_NAMESPACE" >/dev/null 2>&1; then
      project_secret_username_b64="$(printf '%s' "$SNAPSHOT_REGISTRY_USERNAME" | base64 | tr -d '\n')"
      project_secret_password_b64="$(printf '%s' "$project_secret_password" | base64 | tr -d '\n')"
      cat <<EOF | kubectl apply -f -
apiVersion: management.loft.sh/v1
kind: ProjectSecret
metadata:
  name: ${IMAGE_PULL_SOURCE_SECRET_NAME}
  namespace: ${IMAGE_PULL_PROJECT_NAMESPACE}
  labels:
    loft.sh/project-secret-name: ${IMAGE_PULL_SOURCE_SECRET_NAME}
    org: ${ORG_NAME}
    repo: ${REPO_NAME}
spec:
  displayName: ${IMAGE_PULL_PROJECT_SECRET_NAME}
  data:
    username: ${project_secret_username_b64}
    password: ${project_secret_password_b64}
EOF
    else
      echo "[WARN] Could not find namespace ${IMAGE_PULL_PROJECT_NAMESPACE} to create ${IMAGE_PULL_SOURCE_SECRET_NAME}." >&2
    fi
  else
    echo "[WARN] Skipping GHCR shared secret and ${IMAGE_PULL_SOURCE_SECRET_NAME} ProjectSecret creation because snapshot registry credentials were not provided." >&2
  fi
fi

if [[ "$PRIVATE_NODES_ENABLED" == "true" ]]; then
  step "Create the default OrbStack VM for the private-nodes demo"
  require_cmd orb
  require_cmd nohup
  bash vcluster-use-cases/private-nodes/create-orbstack-private-node.sh \
    --machine "$PRIVATE_NODE_VM_NAME" \
    --background
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
   - 1Password vault: ${ONEPASSWORD_VAULT}
4. Confirm Argo CD and vCluster Platform are healthy:
   - kubectl -n argocd get pods
   - kubectl -n vcluster-platform get pods
5. Continue with vind-demo-cluster/README.md if you want the detailed flow.

Enabled use cases:
- ${selected_use_cases}

EOF

if [[ "$PRIVATE_NODES_ENABLED" == "true" ]]; then
  cat <<EOF

Private Nodes:
- default OrbStack VM: ${PRIVATE_NODE_VM_NAME}
- example vCluster instance: private-node-demo
- next step:
  copy the Private Nodes connect command from vCluster Platform and run:
  orb -m ${PRIVATE_NODE_VM_NAME} -u root sh -lc '<connect-command>'

EOF
fi

if [[ -n "$IMAGE_BUILD_LOG" ]]; then
  cat <<EOF

Image build:
- running in background
- pid: ${IMAGE_BUILD_PID}
- log: ${IMAGE_BUILD_LOG}
- follow with: tail -f ${IMAGE_BUILD_LOG}

EOF
fi

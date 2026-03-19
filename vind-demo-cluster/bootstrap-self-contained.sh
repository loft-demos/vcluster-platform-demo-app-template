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
    log_error "Required command not found: $cmd" >&2
    exit 1
  fi
}

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
  _CR='\033[0m'      # reset
  _CDIM='\033[2m'    # dim (timestamps)
  _CINFO='\033[32m'  # green (info)
  _CDONE='\033[92m'  # bright green (done)
  _CWARN='\033[33m'  # yellow (warn)
  _CERR='\033[91m'   # bright red (error)
  _CSTEP='\033[1m'   # bold (step label)
else
  _CR='' _CDIM='' _CINFO='' _CDONE='' _CWARN='' _CERR='' _CSTEP=''
fi
export _CR _CDIM _CINFO _CDONE _CWARN _CERR _CSTEP

_ts()      { date '+%H:%M:%S'; }
log_info()  { printf "${_CDIM}%s${_CR} ${_CINFO}info${_CR}  %s\n"  "$(_ts)" "$*"; }
log_done()  { printf "${_CDIM}%s${_CR} ${_CDONE}done${_CR}  %s\n"  "$(_ts)" "$*"; }
log_warn()  { printf "${_CDIM}%s${_CR} ${_CWARN}warn${_CR}  %s\n"  "$(_ts)" "$*" >&2; }
log_error() { printf "${_CDIM}%s${_CR} ${_CERR}error${_CR} %s\n"   "$(_ts)" "$*" >&2; }

step() {
  STEP_INDEX=$((STEP_INDEX + 1))
  echo
  printf "${_CDIM}%s${_CR} ${_CINFO}info${_CR}  ${_CSTEP}[STEP %s] %s${_CR}\n" "$(_ts)" "$STEP_INDEX" "$1"
}

wait_for_create() {
  # Poll until kubectl succeeds. Args: <attempts> <sleep_sec> <kubectl_args...>
  local attempts="$1" interval="$2"; shift 2
  for _ in $(seq 1 "$attempts"); do
    kubectl "$@" >/dev/null 2>&1 && return 0
    sleep "$interval"
  done
  return 0
}

apply_registry_secrets() {
  require_cmd base64
  require_cmd jq
  local project_secret_password="${SNAPSHOT_REGISTRY_TOKEN:-$SNAPSHOT_REGISTRY_PASSWORD}"

  if [[ -n "$SNAPSHOT_REGISTRY_USERNAME" && -n "$project_secret_password" ]]; then
    wait_for_create 60 2 get namespace vcluster-platform

    if kubectl get namespace vcluster-platform >/dev/null 2>&1; then
      wait_for_create 60 2 get namespace p-api-framework
      wait_for_create 60 2 get namespace p-auth-core

      ghcr_auth_b64="$(printf '%s:%s' "$SNAPSHOT_REGISTRY_USERNAME" "$project_secret_password" | base64 | tr -d '\n')"
      ghcr_dockerconfigjson="$(
        jq -cn \
          --arg username "$SNAPSHOT_REGISTRY_USERNAME" \
          --arg password "$project_secret_password" \
          --arg auth "$ghcr_auth_b64" \
          '{auths: {"forgejo-http.forgejo.svc.cluster.local:3000": {username: $username, password: $password, auth: $auth}}}'
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
        log_warn "Could not find p-api-framework and p-auth-core to create ghcr-login-secret projections." >&2
      fi
    else
      log_warn "Could not find namespace vcluster-platform to create ghcr-login-secret." >&2
    fi

    wait_for_create 60 2 get namespace "$IMAGE_PULL_PROJECT_NAMESPACE"

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
      log_warn "Could not find namespace ${IMAGE_PULL_PROJECT_NAMESPACE} to create ${IMAGE_PULL_SOURCE_SECRET_NAME}." >&2
    fi
  else
    log_warn "Skipping GHCR shared secret and ${IMAGE_PULL_SOURCE_SECRET_NAME} ProjectSecret creation because snapshot registry credentials were not provided." >&2
  fi
}

annotate_loft_cluster() {
  local domain_prefix="$1"
  local domain_name="$2"
  local sleep_time_zone="$3"
  local cluster_annotated="false"

  log_info "Waiting for vCluster Platform deployment to become available"
  for attempt in $(seq 1 30); do
    if kubectl -n vcluster-platform wait --for=condition=Available deploy/loft --timeout=10s >/dev/null 2>&1; then
      log_info "vCluster Platform deployment is available"
      break
    fi
    if (( attempt % 3 == 0 )); then
      log_info "Still waiting for deploy/loft (${attempt}/30)"
      kubectl get deploy,pods -n vcluster-platform --no-headers 2>/dev/null || true
    fi
  done

  log_info "Waiting for clusters.management.loft.sh/loft-cluster"
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
      log_info "Still waiting for cluster/loft-cluster (${attempt}/60)"
    fi
    sleep 2
  done

  if [[ "$cluster_annotated" == "true" ]]; then
    log_info "Annotated cluster/loft-cluster"
  else
    log_warn "Could not find cluster/loft-cluster to annotate yet." >&2
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
      log_info "Applied NoSchedule taint to node ${control_plane_node}"
    else
      log_warn "Could not find a control plane node to taint." >&2
    fi
  else
    log_warn "Timed out waiting for nodes to become ready before tainting the control plane node." >&2
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
GIT_BASE_URL_AUTHED=""
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
SNAPSHOT_REGISTRY_USERNAME="${SNAPSHOT_REGISTRY_USERNAME:-${FORGEJO_USERNAME}}"
SNAPSHOT_REGISTRY_TOKEN="${SNAPSHOT_REGISTRY_TOKEN:-${FORGEJO_TOKEN:-}}"
SNAPSHOT_REGISTRY_PASSWORD="${SNAPSHOT_REGISTRY_PASSWORD:-${FORGEJO_PASSWORD}}"

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
      log_error "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd bash

if [[ "$SKIP_VIND" != "true" && -z "$LICENSE_TOKEN" ]]; then
  log_error "--license-token or LICENSE_TOKEN is required unless --skip-vind is used." >&2
  exit 1
fi

if [[ ! "$CONTROL_PLANE_NODE_COUNT" =~ ^[0-9]+$ || "$CONTROL_PLANE_NODE_COUNT" -ne 1 ]]; then
  log_error "--control-plane-nodes must be 1 for this vind configuration." >&2
  exit 1
fi

if [[ ! "$WORKER_NODE_COUNT" =~ ^[0-9]+$ ]]; then
  log_error "--worker-nodes must be a non-negative integer." >&2
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
  # Use the public Forgejo URL so Argo CD app source URLs match webhook payloads.
  GIT_BASE_URL="${FORGEJO_URL%/}"
fi

if [[ -z "$GIT_BASE_URL_AUTHED" ]]; then
  # Internal URL with embedded credentials for contexts that cannot use HTTPS
  # (e.g. vCluster Platform NodeProvider Terraform clone).
  GIT_BASE_URL_AUTHED="http://${FORGEJO_USERNAME}:${FORGEJO_PASSWORD}@forgejo-http.forgejo.svc.cluster.local:3000"
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

# Warn about and remove vind-disabled use cases from the active selection.
_active_use_cases=""
while IFS= read -r _uc; do
  [[ -z "$_uc" ]] && continue
  if use_case_vind_disabled "$_uc"; then
    log_warn "Use case '$_uc' is temporarily disabled in vind and will not be activated."
    log_warn "The overlay code is preserved and can be re-enabled once the upstream blocker is resolved."
  else
    _active_use_cases="${_active_use_cases:+${_active_use_cases}
}${_uc}"
  fi
done < <(printf '%s\n' "$resolved_use_case_selection" | tr ',' '\n')
resolved_use_case_selection="$_active_use_cases"

PRIVATE_NODES_ENABLED="false"
AUTO_NODES_ENABLED="false"
argocd_token=""
if use_case_list_contains "$resolved_use_case_selection" "private-nodes"; then
  PRIVATE_NODES_ENABLED="true"
fi
if use_case_list_contains "$resolved_use_case_selection" "auto-nodes"; then
  AUTO_NODES_ENABLED="true"
fi

vcp_domain_prefix="${VCP_HOST%%.*}"
if [[ "$VCP_HOST" == *.* ]]; then
  vcp_domain="${VCP_HOST#*.}"
else
  vcp_domain="local"
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
    --git-base-url-authed "$GIT_BASE_URL_AUTHED" \
    --git-public-url "$GIT_PUBLIC_URL" \
    --image-repository-prefix "$IMAGE_REPOSITORY_PREFIX" \
    --oci-registry-host "$FORGEJO_HOST" \
    --snapshot-oci-repository "forgejo-http.forgejo.svc.cluster.local:3000/${FORGEJO_OWNER}/${REPO_NAME}" \
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
    # Wait for the Forgejo pod to be Ready before polling the external URL —
    # the k8s readiness check completes much sooner than the full ingress path.
    if command -v kubectl >/dev/null 2>&1; then
      kubectl -n forgejo wait --for=condition=Ready pod \
        -l "app.kubernetes.io/name=forgejo" \
        --timeout=300s >/dev/null 2>&1 || true
    fi

    log_info "Waiting for Forgejo API at ${FORGEJO_URL}/api/healthz"
    for attempt in $(seq 1 60); do
      if curl -ksSf "${FORGEJO_URL}/api/healthz" >/dev/null 2>&1; then
        log_info "Forgejo API is reachable"
        break
      fi
      if (( attempt % 5 == 0 )); then
        log_info "Still waiting for Forgejo API (${attempt}/60)"
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

    if [[ "$AUTO_NODES_ENABLED" == "true" ]]; then
      step "Mirror vcluster-auto-nodes-pod to Forgejo"
      _demo_repo_dir="$(pwd)"
      git submodule update --init vcluster-auto-nodes-pod
      (
        cd "$_demo_repo_dir/vcluster-auto-nodes-pod"
        bash "$_demo_repo_dir/scripts/bootstrap-forgejo-repo.sh" \
          --forgejo-url "$FORGEJO_URL" \
          --username "$FORGEJO_USERNAME" \
          "${forgejo_auth_args[@]}" \
          --owner "$FORGEJO_OWNER" \
          --owner-type "$FORGEJO_OWNER_TYPE" \
          --repo "vcluster-auto-nodes-pod" \
          --visibility public \
          --current-branch-only \
          --skip-tags
      ) || log_warn "Could not push vcluster-auto-nodes-pod to Forgejo."
    fi
  else
    log_info "Skipping Forgejo bootstrap because --repo-name was not provided."
  fi
fi

# The replace-text step dirtied the working tree with actual values so they
# could be captured by --include-working-tree above. Restore now so the local
# git repo stays clean and the replacements cannot be accidentally committed
# back to the template on the upstream remote.
if [[ "$SKIP_REPLACE" != "true" && "$SKIP_FORGEJO" != "true" ]]; then
  git restore . >/dev/null 2>&1 || true
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
    log_info "Image build running in background."
    log_info "PID: $IMAGE_BUILD_PID"
    log_info "Log: $IMAGE_BUILD_LOG"
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
    log_warn "Skipping Argo CD bootstrap because --repo-name and --org-name were not provided." >&2
  else
    argocd_api_webhook_url="http://argocd-server.argocd.svc.cluster.local/api/webhook"
    argocd_appset_webhook_url="http://forgejo-pr-webhook-adapter.argocd.svc.cluster.local:8080/api/webhook"

    kubectl -n argocd wait --for=condition=Available deploy/argocd-server --timeout=300s >/dev/null 2>&1 || true
    kubectl -n argocd wait --for=condition=Available deploy/argocd-applicationset-controller --timeout=300s >/dev/null 2>&1 || true
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

    # Trust the OrbStack self-signed CA before applying the root application so
    # argocd-repo-server can immediately clone from the public Forgejo HTTPS URL
    # (forgejo.vcp.local). Without this, the root app sync fails with an x509
    # error and the bootstrap hangs waiting for forgejo-pr-webhook-adapter.
    _orbstack_ca="$(security find-certificate -c "OrbStack" -p 2>/dev/null || true)"
    if [[ -n "$_orbstack_ca" ]]; then
      kubectl create configmap argocd-tls-certs-cm \
        --namespace argocd \
        --from-literal="${FORGEJO_HOST}=${_orbstack_ca}" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
      # Restart repo-server so it picks up the new cert immediately rather than
      # waiting for its configmap watch to fire.
      kubectl -n argocd rollout restart deploy/argocd-repo-server >/dev/null 2>&1 || true
      kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=60s >/dev/null 2>&1 || true
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

    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vcluster-gitops
  namespace: argocd
spec:
  destination:
    server: https://kubernetes.default.svc
  project: default
  source:
    path: vcluster-gitops/overlays/local-contained
    repoURL: ${GIT_BASE_URL}/${ORG_NAME}/${REPO_NAME}.git
    targetRevision: HEAD
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

    # The adapter deployment is created by Argo CD syncing the root application,
    # not by kubectl directly. Wait for the deployment to be created first, then
    # wait for it to become Available.
    wait_for_create 60 5 -n argocd get deploy/forgejo-pr-webhook-adapter
    kubectl -n argocd wait --for=condition=Available deploy/forgejo-pr-webhook-adapter --timeout=180s >/dev/null 2>&1 || true

    # The webhook listener can miss server.secretkey on first startup in the
    # self-contained path. Restart once so the listener comes up before we
    # register Forgejo webhooks against it.
    kubectl -n argocd rollout restart deploy/argocd-applicationset-controller >/dev/null 2>&1 || true
    kubectl -n argocd rollout status deploy/argocd-applicationset-controller --timeout=180s >/dev/null 2>&1 || true

    step "Configure Forgejo webhooks for Argo CD"
    bash scripts/configure-forgejo-webhook.sh \
      --forgejo-url "$FORGEJO_URL" \
      --username "$FORGEJO_USERNAME" \
      --token "$argocd_token" \
      --owner "$ORG_NAME" \
      --repo "$REPO_NAME" \
      --webhook-url "$argocd_api_webhook_url" \
      --type gogs \
      --events push

    bash scripts/configure-forgejo-webhook.sh \
      --forgejo-url "$FORGEJO_URL" \
      --username "$FORGEJO_USERNAME" \
      --token "$argocd_token" \
      --owner "$ORG_NAME" \
      --repo "$REPO_NAME" \
      --webhook-url "$argocd_appset_webhook_url" \
      --type gitea \
      --events pull_request

    step "Configure Forgejo repo labels for PR workflows"
    _forgejo_label() {
      bash scripts/configure-forgejo-labels.sh \
        --forgejo-url "$FORGEJO_URL" \
        --username "$FORGEJO_USERNAME" \
        --token "$argocd_token" \
        --owner "$ORG_NAME" \
        --repo "$REPO_NAME" \
        --label-name "$1" \
        --label-color "$2" \
        --label-description "$3"
    }
    _forgejo_label "deploy/argocd-vcluster-preview" "ee7d3b" "Creates PR preview vCluster instances with matrix of Kubernetes versions via Argo CD"
    _forgejo_label "deploy/flux-vcluster-preview"   "c5def5" "PR preview vCluster instances with a matrix of Kubernetes versions via Flux"
    _forgejo_label "e2e vCluster"                   "ee7d3b" "Run e2e tests on PR with vCluster"
    _forgejo_label "create-pr-vcluster-external-argocd" "ee7d3b" "Triggers the creation of a vCluster for a Pull Request via Argo CD"
    _forgejo_label "preview"                        "ee7d3b" "Creates vCluster preview environment for a Pull Request with Argo CD"
    _forgejo_label "preview-cluster-ready"          "ee7d3b" "Triggers Argo CD application set for PR"
    unset -f _forgejo_label
  fi
fi

if command -v kubectl >/dev/null 2>&1 && use_case_list_contains "$resolved_use_case_selection" "flux"; then
  step "Configure Forgejo webhook for Flux"

  flux_forgejo_token="${argocd_token:-${FORGEJO_TOKEN:-}}"
  if [[ -z "$flux_forgejo_token" ]]; then
    flux_forgejo_token="$FORGEJO_PASSWORD"
  fi

  # Generate a random HMAC secret for the Flux Receiver and store it as a
  # k8s Secret in p-auth-core. The same value is registered as the Forgejo
  # webhook secret so Flux can verify incoming payloads. The token is never
  # written to source control.
  flux_receiver_token="$(openssl rand -hex 20)"
  wait_for_create 60 5 get namespace p-auth-core
  kubectl create secret generic pr-github-receiver-token \
    --namespace p-auth-core \
    --from-literal=token="$flux_receiver_token" \
    --dry-run=client -o yaml | kubectl apply -f -

  # Create the Forgejo API credentials secret in p-auth-core so Flux Providers
  # and the ResourceSetInputProvider can authenticate with Forgejo's API.
  # GiteaPullRequest type requires both 'username' and 'password' fields.
  kubectl create secret generic loft-demo-org-cred \
    --namespace p-auth-core \
    --from-literal=username="$FORGEJO_USERNAME" \
    --from-literal=password="$flux_forgejo_token" \
    --from-literal=token="$flux_forgejo_token" \
    --dry-run=client -o yaml | kubectl apply -f -

  # Create HTTP basic-auth credentials for Flux GitRepository resources so
  # they can clone the private Forgejo repo without TLS certificate errors.
  # The same secret is pre-created in p-vcluster-flux-demo (created by Argo CD
  # wave-0) so the wave-2 GitRepository/vcluster-flux-demo can authenticate.
  kubectl create secret generic forgejo-git-credentials \
    --namespace p-auth-core \
    --from-literal=username="$FORGEJO_USERNAME" \
    --from-literal=password="$flux_forgejo_token" \
    --dry-run=client -o yaml | kubectl apply -f -
  wait_for_create 120 5 get namespace p-vcluster-flux-demo
  if kubectl get namespace p-vcluster-flux-demo >/dev/null 2>&1; then
    kubectl create secret generic forgejo-git-credentials \
      --namespace p-vcluster-flux-demo \
      --from-literal=username="$FORGEJO_USERNAME" \
      --from-literal=password="$flux_forgejo_token" \
      --dry-run=client -o yaml | kubectl apply -f -
  else
    log_warn "p-vcluster-flux-demo not ready yet — forgejo-git-credentials will be missing there." >&2
    log_warn "Re-run after flux-manifests syncs to create it:" >&2
    log_warn "  kubectl create secret generic forgejo-git-credentials \\" >&2
    log_warn "    --namespace p-vcluster-flux-demo \\" >&2
    log_warn "    --from-literal=username=\"$FORGEJO_USERNAME\" \\" >&2
    log_warn "    --from-literal=password=\"\$FORGEJO_TOKEN\"" >&2
  fi

  if ! bash scripts/configure-flux-webhook.sh \
    --forgejo-url "$FORGEJO_URL" \
    --username "$FORGEJO_USERNAME" \
    --token "$flux_forgejo_token" \
    --owner "$ORG_NAME" \
    --repo "$REPO_NAME" \
    --vcluster-name "$VCLUSTER_NAME" \
    --base-domain "$BASE_DOMAIN" \
    --webhook-secret "$flux_receiver_token"; then
    log_warn "Flux webhook configuration did not complete — the Flux Receiver" >&2
    log_warn "may not be ready yet. Re-run once the cluster is healthy:" >&2
    log_warn "  bash scripts/configure-flux-webhook.sh \\" >&2
    log_warn "    --forgejo-url \"$FORGEJO_URL\" \\" >&2
    log_warn "    --username \"$FORGEJO_USERNAME\" \\" >&2
    log_warn "    --token \"\$FORGEJO_TOKEN\" \\" >&2
    log_warn "    --owner \"$ORG_NAME\" \\" >&2
    log_warn "    --repo \"$REPO_NAME\" \\" >&2
    log_warn "    --vcluster-name \"$VCLUSTER_NAME\" \\" >&2
    log_warn "    --base-domain \"$BASE_DOMAIN\"" >&2
  fi
fi

  # vCP nav bar buttons (vCluster Docs, Forgejo Repo, Flux UI) are set via
  # the vCluster Platform Helm values in vind-demo-cluster/vcluster.yaml and
  # rendered at vind install time — no runtime patching needed.

if command -v kubectl >/dev/null 2>&1; then
  step "Apply cluster-local use case labels"
  require_cmd kubectl
  apply_cluster_local_secret "$VCP_HOST" "$vcp_domain_prefix" "$vcp_domain" "$USE_CASES"

  step "Create the demo-admin-access-key ProjectSecret"
  wait_for_create 60 5 get namespace p-auth-core
  _access_key="$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 64)"
  _connected_key="$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 64)"
  kubectl create secret generic demo-admin-access-key \
    --namespace p-auth-core \
    --from-literal=accessKey="$_access_key" \
    --from-literal=connectedHostClusterAccessKey="$_connected_key" \
    --dry-run=client -o yaml | kubectl apply -f -

  step "Create the default Platform registry auth secrets"
  apply_registry_secrets
fi

if use_case_list_contains "$resolved_use_case_selection" "auto-snapshots" && command -v kubectl >/dev/null 2>&1; then
  step "Create MinIO root credentials for auto-snapshots S3 storage"
  _minio_access_key="$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 20)"
  _minio_secret_key="$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)"

  # minio namespace is created by ArgoCD from the auto-snapshots local-contained overlay;
  # pre-create it here so the minio-auth secret is ready before the MinIO pod starts.
  kubectl create namespace minio --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret generic minio-auth \
    --namespace minio \
    --from-literal=access-key="$_minio_access_key" \
    --from-literal=secret-key="$_minio_secret_key" \
    --dry-run=client -o yaml | kubectl apply -f -

  step "Create MinIO snapshot service account and ProjectSecret"
  # Wait for MinIO to be deployed and ready by Argo CD before creating the service account.
  wait_for_create 120 5 get deployment minio -n minio
  kubectl rollout status deployment/minio -n minio --timeout=120s || true

  _snapshot_access_key="$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 20)"
  _snapshot_secret_key="$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)"

  kubectl run mc-svcacct -n minio --image=quay.io/minio/mc:RELEASE.2024-07-31T15-58-33Z --restart=Never \
    --command -- /bin/sh -c "
      mc alias set local http://minio.minio.svc.cluster.local:9000 '$_minio_access_key' '$_minio_secret_key'
      mc admin user svcacct add local '$_minio_access_key' \
        --access-key '$_snapshot_access_key' \
        --secret-key '$_snapshot_secret_key' \
        --description 'vCluster auto-snapshot controller'
      echo DONE
    "
  wait_for_create 60 3 get pod mc-svcacct -n minio
  kubectl wait pod/mc-svcacct -n minio --for=condition=Ready --timeout=30s 2>/dev/null || true
  kubectl wait pod/mc-svcacct -n minio --for=jsonpath='{.status.phase}'=Succeeded --timeout=60s 2>/dev/null || true
  kubectl logs -n minio mc-svcacct 2>/dev/null || true
  kubectl delete pod -n minio mc-svcacct --ignore-not-found

  # ProjectSecret backed by a plain Secret — patch .data directly.
  # AWS_SESSION_TOKEN is unused by MinIO but required by the vCluster credential format.
  _snapshot_access_key_b64="$(printf '%s' "$_snapshot_access_key" | base64 | tr -d '\n')"
  _snapshot_secret_key_b64="$(printf '%s' "$_snapshot_secret_key" | base64 | tr -d '\n')"
  wait_for_create 60 5 get namespace p-default
  # Create as a plain Secret (the management.loft.sh ProjectSecret is backed by v1/Secret).
  kubectl create secret generic minio-snapshot-cred \
    --namespace p-default \
    --from-literal=AWS_ACCESS_KEY_ID="$_snapshot_access_key" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$_snapshot_secret_key" \
    --from-literal=AWS_SESSION_TOKEN="" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl label secret minio-snapshot-cred -n p-default \
    loft.sh/project-secret-name=minio-snapshot-cred \
    loft.sh/project-secret=true --overwrite
  kubectl annotate secret minio-snapshot-cred -n p-default \
    loft.sh/project-secret-displayname=minio-snapshot-cred \
    loft.sh/project-secret-description="" --overwrite
fi


if [[ "$PRIVATE_NODES_ENABLED" == "true" ]]; then
  step "Create the default OrbStack VM for the private-nodes demo"
  require_cmd orb
  require_cmd nohup
  bash vcluster-use-cases/private-nodes/create-orbstack-private-node.sh \
    --machine "$PRIVATE_NODE_VM_NAME" \
    --background
fi

if [[ "$AUTO_NODES_ENABLED" == "true" ]] && command -v kubectl >/dev/null 2>&1; then
  step "Create Forgejo git credential secret for the NodeProvider"
  wait_for_create 60 5 get namespace vcluster-platform
  kubectl create secret generic forgejo-node-provider-cred \
    --namespace vcluster-platform \
    --from-literal=username="$FORGEJO_USERNAME" \
    --from-literal=password="${FORGEJO_PASSWORD:-$FORGEJO_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

minio_access_key=""
minio_secret_key=""
if use_case_list_contains "$resolved_use_case_selection" "auto-snapshots" && command -v kubectl >/dev/null 2>&1; then
  minio_access_key="$(kubectl get secret minio-auth -n minio -o jsonpath='{.data.access-key}' 2>/dev/null | base64 -d || true)"
  minio_secret_key="$(kubectl get secret minio-auth -n minio -o jsonpath='{.data.secret-key}' 2>/dev/null | base64 -d || true)"
  minio_snapshot_access_key="$(kubectl get secret minio-snapshot-cred -n p-default -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' 2>/dev/null | base64 -d || true)"
  minio_snapshot_secret_key="$(kubectl get secret minio-snapshot-cred -n p-default -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' 2>/dev/null | base64 -d || true)"
fi

argocd_password=""
if command -v kubectl >/dev/null 2>&1; then
  log_info "Looking up the Argo CD initial admin password"
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
   - url:      https://${ARGOCD_HOST}
   - username: admin
   - password: ${argocd_password:-<not available yet>}
2. Open the local URLs:
   - vCluster Platform: https://${VCP_HOST}
   - Argo CD:           https://${ARGOCD_HOST}
   - Forgejo:           https://${FORGEJO_HOST}
EOF

if [[ -n "$minio_access_key" ]]; then
  cat <<EOF
   - MinIO console:     https://minio.${VCP_HOST}
MinIO root credentials (console login):
   - access key: ${minio_access_key}
   - secret key: ${minio_secret_key}
MinIO snapshot service account (S3 access key for vCluster snapshots):
   - access key: ${minio_snapshot_access_key:-<created during bootstrap>}
   - secret key: ${minio_snapshot_secret_key:-<created during bootstrap>}
EOF
fi

cat <<EOF
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

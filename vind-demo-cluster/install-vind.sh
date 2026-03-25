#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./use-case-labels.sh
source "$(dirname "$0")/use-case-labels.sh"

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
    --vcp-version 4.8.0 \
    --vcp-host vcp.local \
    --repo-name vcp-gitops \
    --worker-nodes 2 \
    --use-cases eso,auto-snapshots

Options:
  --cluster-name NAME    Optional. Defaults to vcp.
  --values-file PATH     Optional. Defaults to vind-demo-cluster/vcluster.yaml.
  --license-token TOKEN  Required unless LICENSE_TOKEN is already exported.
  --vcp-version VERSION  Optional. Defaults to 4.8.0.
  --repo-name NAME       Optional. Defaults to vcp-gitops.
  --org-name NAME        Optional. Defaults to vcluster-demos.
  --vcluster-name NAME   Optional. Defaults to repo name with trailing -app removed.
  --control-plane-nodes COUNT
                         Optional. Defaults to 1. This vind config currently
                         supports exactly one control plane node.
  --worker-nodes COUNT   Optional. Defaults to 2.
  --docker-arg ARG       Optional. Repeatable extra docker-run arg passed via
                         experimental.docker.args. Experimental.
  --docker-storage-opt-size SIZE
                         Optional shorthand for --docker-arg
                         --storage-opt=size=<SIZE>. Experimental.
  --vcp-host HOST        Optional. Defaults to vcp.local.
  --argocd-host HOST     Optional. Defaults to argocd.<vcp-host>.
  --forgejo-host HOST    Optional. Defaults to forgejo.<vcp-host>.
  --forgejo-admin-user NAME
                         Optional. Defaults to demo-admin.
  --forgejo-admin-password VALUE
                         Optional. Defaults to FORGEJO_ADMIN_PASSWORD or
                         vcluster-demo-admin.
  --sleep-time-zone TZ   Optional. Defaults to America/New_York.
  --use-cases LIST       Optional. Comma-separated use cases or presets.
                         Defaults to "default" which currently means `eso`.
                         Example: eso,auto-snapshots,flux
                         Example: all,-crossplane,-rancher
  --list-use-cases       Print the supported use cases and exit.
  --orbstack-env-file PATH
                         Optional. Defaults to orbstack-domains/.env.<cluster-name>.
  --skip-cluster-annotation
                         Optional. Skip annotating cluster/loft-cluster.
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

yaml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

if [[ -z "${_CR+set}" ]]; then
  # Not inherited from a parent script — detect tty ourselves
  if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    _CR='\033[0m' _CDIM='\033[2m' _CINFO='\033[32m' _CDONE='\033[92m' _CWARN='\033[33m' _CERR='\033[91m'
  else
    _CR='' _CDIM='' _CINFO='' _CDONE='' _CWARN='' _CERR=''
  fi
fi

_ts()      { date '+%H:%M:%S'; }
log_info()  { printf "${_CDIM}%s${_CR} ${_CINFO}info${_CR}  %s\n"  "$(_ts)" "$*"; }
log_done()  { printf "${_CDIM}%s${_CR} ${_CDONE}done${_CR}  %s\n"  "$(_ts)" "$*"; }
log_warn()  { printf "${_CDIM}%s${_CR} ${_CWARN}warn${_CR}  %s\n"  "$(_ts)" "$*" >&2; }
log_error() { printf "${_CDIM}%s${_CR} ${_CERR}error${_CR} %s\n"   "$(_ts)" "$*" >&2; }

CLUSTER_NAME="vcp"
VALUES_FILE="vind-demo-cluster/vcluster.yaml"
LICENSE_TOKEN="${LICENSE_TOKEN:-}"
VCP_VERSION="${VCP_VERSION:-4.8.0}"
REPO_NAME="vcp-gitops"
ORG_NAME="vcluster-demos"
VCLUSTER_NAME=""
CONTROL_PLANE_NODE_COUNT="${CONTROL_PLANE_NODE_COUNT:-1}"
WORKER_NODE_COUNT="${WORKER_NODE_COUNT:-2}"
DOCKER_STORAGE_OPT_SIZE="${DOCKER_STORAGE_OPT_SIZE:-}"
DOCKER_ARGS=()
VCP_HOST="${VCP_HOST:-vcp.local}"
ARGOCD_HOST=""
FORGEJO_HOST=""
FORGEJO_ADMIN_USER="${FORGEJO_ADMIN_USER:-demo-admin}"
FORGEJO_ADMIN_PASSWORD="${FORGEJO_ADMIN_PASSWORD:-vcluster-demo-admin}"
SLEEP_TIME_ZONE="${SLEEP_TIME_ZONE:-America/New_York}"
USE_CASES="${USE_CASES:-$DEFAULT_USE_CASE_SPEC}"
ORBSTACK_ENV_FILE=""
SKIP_ORBSTACK_DOMAINS="false"
SKIP_CLUSTER_ANNOTATION="false"
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
    --control-plane-nodes)
      CONTROL_PLANE_NODE_COUNT="${2:-}"
      shift 2
      ;;
    --worker-nodes)
      WORKER_NODE_COUNT="${2:-}"
      shift 2
      ;;
    --docker-arg)
      DOCKER_ARGS+=("${2:-}")
      shift 2
      ;;
    --docker-storage-opt-size)
      DOCKER_STORAGE_OPT_SIZE="${2:-}"
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
    --use-cases)
      USE_CASES="${2:-}"
      shift 2
      ;;
    --list-use-cases)
      print_known_use_cases
      exit 0
      ;;
    --orbstack-env-file)
      ORBSTACK_ENV_FILE="${2:-}"
      shift 2
      ;;
    --skip-cluster-annotation)
      SKIP_CLUSTER_ANNOTATION="true"
      shift
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
require_cmd helm
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

if [[ -n "$DOCKER_STORAGE_OPT_SIZE" ]]; then
  DOCKER_ARGS+=("--storage-opt=size=${DOCKER_STORAGE_OPT_SIZE}")
fi

if [[ -z "$ARGOCD_HOST" ]]; then
  ARGOCD_HOST="argocd.${VCP_HOST}"
fi

if [[ -z "$VCLUSTER_NAME" ]]; then
  VCLUSTER_NAME="${REPO_NAME%-app}"
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

cluster_local_use_case_labels="$(render_cluster_local_labels "$USE_CASES" '            ')"
selected_use_cases="$(selected_use_cases_csv "$USE_CASES")"
selected_use_case_lines="$(resolve_use_case_selection "$USE_CASES")"
declare -a docker_args_copy=()

set +u
docker_args_copy=("${DOCKER_ARGS[@]}")
set -u

worker_nodes_yaml="      []"
docker_args_yaml=""
if [[ "${#docker_args_copy[@]}" -gt 0 ]]; then
  docker_args_yaml="    args:
"
  set +u
  for docker_arg in "${docker_args_copy[@]}"; do
    docker_args_yaml="${docker_args_yaml}      - \"$(yaml_escape "$docker_arg")\"
"
  done
  set -u
  docker_args_yaml="${docker_args_yaml%$'\n'}"
fi

if [[ "$WORKER_NODE_COUNT" -gt 0 ]]; then
  worker_nodes_yaml=""
  for worker_index in $(seq 1 "$WORKER_NODE_COUNT"); do
    worker_nodes_yaml="${worker_nodes_yaml}      - name: worker-${worker_index}
"
    if [[ "${#docker_args_copy[@]}" -gt 0 ]]; then
      worker_nodes_yaml="${worker_nodes_yaml}        args:
"
      set +u
      for docker_arg in "${docker_args_copy[@]}"; do
        worker_nodes_yaml="${worker_nodes_yaml}          - \"$(yaml_escape "$docker_arg")\"
"
      done
      set -u
    fi
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
export VIND_DOCKER_NODES="$worker_nodes_yaml" VIND_DOCKER_ARGS="$docker_args_yaml"
export CLUSTER_LOCAL_USE_CASE_LABELS="$cluster_local_use_case_labels"
export REPO_NAME ORG_NAME VCLUSTER_NAME
perl -0pi -e '
  s/__VCP_PLATFORM_VERSION__/$ENV{VCP_VERSION}/g;
  s/__VCP_LOFT_HOST__/$ENV{VCP_HOST}/g;
  s/__VCP_DOMAIN_PREFIX__/$ENV{VCP_DOMAIN_PREFIX}/g;
  s/__VCP_DOMAIN__/$ENV{VCP_DOMAIN}/g;
  s/__FORGEJO_HOST__/$ENV{FORGEJO_HOST}/g;
  s/__FORGEJO_ADMIN_USER__/$ENV{FORGEJO_ADMIN_USER}/g;
  s/__FORGEJO_ADMIN_PASSWORD__/$ENV{FORGEJO_ADMIN_PASSWORD}/g;
  s/__VIND_DOCKER_ARGS__/$ENV{VIND_DOCKER_ARGS}/g;
  s/__VIND_DOCKER_NODES__/$ENV{VIND_DOCKER_NODES}/g;
  s/__CLUSTER_LOCAL_USE_CASE_LABELS__/$ENV{CLUSTER_LOCAL_USE_CASE_LABELS}/g;
  s/__REPO_NAME__/$ENV{REPO_NAME}/g;
  s/__ORG_NAME__/$ENV{ORG_NAME}/g;
  s/__VCLUSTER_NAME__/$ENV{VCLUSTER_NAME}/g;
' "$rendered_values"

log_info "Creating or upgrading vind cluster '$CLUSTER_NAME'"
log_info "Values file template: $VALUES_FILE"
log_info "Rendered values file: $rendered_values"
log_info "vCluster Platform version: $VCP_VERSION"
log_info "Repo: $ORG_NAME/$REPO_NAME"
log_info "Control plane nodes: $CONTROL_PLANE_NODE_COUNT"
log_info "Worker nodes: $WORKER_NODE_COUNT"
if [[ "${#docker_args_copy[@]}" -gt 0 ]]; then
  log_info "Experimental docker args: ${docker_args_copy[*]}"
fi
log_info "vCluster Platform host: $VCP_HOST"
log_info "Forgejo host: $FORGEJO_HOST"
log_info "Forgejo admin user: $FORGEJO_ADMIN_USER"
log_info "Sleep time zone: $SLEEP_TIME_ZONE"
log_info "Enabled use cases: $selected_use_cases"

vcluster create "$CLUSTER_NAME" --driver docker --upgrade --add=false --values "$rendered_values"

log_info "Applying browser ingress resources"
bash vind-demo-cluster/apply-browser-ingresses.sh \
  --vcp-host "$VCP_HOST" \
  --argocd-host "$ARGOCD_HOST" \
  --forgejo-host "$FORGEJO_HOST"

# Render the vCP Helm values from its dedicated template file.
_vcp_values_tmpl="$(dirname "$VALUES_FILE")/vcp-platform-values.yaml"
_vcp_values_rendered="$(mktemp "${TMPDIR:-/tmp}/vcp-platform-values.XXXXXX")"
trap 'rm -f "$rendered_values" "$_vcp_values_rendered"' EXIT

_kargo_nav_button=""
if use_case_list_contains "$selected_use_case_lines" "continuous-promotion"; then
  _kargo_nav_button="- link: \"https://kargo.${VCP_HOST}/\"
        icon: \"https://kargo.${VCP_HOST}/kargo-logo-white.png\"
        text: \"Kargo\"
        position: TopEnd"
fi
export KARGO_NAV_BUTTON="$_kargo_nav_button"

cp "$_vcp_values_tmpl" "$_vcp_values_rendered"
perl -0pi -e '
  s/__VCP_LICENSE_TOKEN__/$ENV{LICENSE_TOKEN}/g;
  s/__VCP_LOFT_HOST__/$ENV{VCP_HOST}/g;
  s/__FORGEJO_HOST__/$ENV{FORGEJO_HOST}/g;
  s/__VCLUSTER_NAME__/$ENV{VCLUSTER_NAME}/g;
  s/__KARGO_NAV_BUTTON__/$ENV{KARGO_NAV_BUTTON}/g;
' "$_vcp_values_rendered"

# Install vCluster Platform in the background so OrbStack domain setup and
# other post-create work can run in parallel.
log_info "Installing vCluster Platform ${VCP_VERSION} via Helm (background)"
helm upgrade --install vcluster-platform vcluster-platform \
  --repo https://charts.loft.sh/ \
  --version "$VCP_VERSION" \
  --namespace vcluster-platform \
  --create-namespace \
  --values "$_vcp_values_rendered" \
  --timeout 15m \
  --wait &
_vcp_helm_pid=$!

if [[ "$SKIP_ORBSTACK_DOMAINS" != "true" ]]; then
  if ! bash vind-demo-cluster/start-orbstack-domains.sh \
    --cluster-name "$CLUSTER_NAME" \
    --vcp-host "$VCP_HOST" \
    --argocd-host "$ARGOCD_HOST" \
    --forgejo-host "$FORGEJO_HOST" \
    --env-file "$ORBSTACK_ENV_FILE"; then
    log_warn "Automatic OrbStack domain setup failed."
    log_warn "You can rerun vind-demo-cluster/start-orbstack-domains.sh after the services are ready."
  fi
fi

log_info "Waiting for vCluster Platform Helm install to complete"
if ! wait "$_vcp_helm_pid"; then
  log_warn "vCluster Platform Helm install exited non-zero — check the output above."
fi

if [[ "$SKIP_CLUSTER_ANNOTATION" != "true" ]]; then
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
  cluster_annotated="false"
  for attempt in $(seq 1 60); do
    if kubectl get clusters.management.loft.sh loft-cluster >/dev/null 2>&1; then
      kubectl annotate --overwrite clusters.management.loft.sh loft-cluster \
        "domainPrefix=${vcp_domain_prefix}" \
        "domain=${vcp_domain}" \
        "sleepTimeZone=${SLEEP_TIME_ZONE}" >/dev/null
      cluster_annotated="true"
      break
    fi
    if (( attempt % 5 == 0 )); then
      log_info "Still waiting for cluster/loft-cluster (${attempt}/60)"
    fi
    sleep 2
  done

  if [[ "$cluster_annotated" == "true" ]]; then
    log_done "Annotated cluster/loft-cluster"
  elif ! kubectl get clusters.management.loft.sh loft-cluster >/dev/null 2>&1; then
    log_warn "Could not find cluster/loft-cluster to annotate yet."
  fi
fi

if [[ "$SKIP_SUMMARY" == "true" ]]; then
  exit 0
fi

log_done "vind cluster '$CLUSTER_NAME' is ready."

cat <<EOF

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
   - http://$FORGEJO_HOST
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

#!/usr/bin/env bash

DEFAULT_USE_CASE_SPEC="default"
DEFAULT_USE_CASES="eso"

# Use cases listed here are excluded from vind activation.
# The code and overlays remain in place; re-enable by removing the entry once the
# underlying blocker is resolved.
vind_disabled_use_cases() {
  cat <<'EOF'
# auto-snapshots: S3-compatible endpoint support broken in vCluster auto-snapshot controller
# Tracking: https://github.com/loft-sh/vcluster/issues — targeted April release
auto-snapshots
EOF
}

# Returns 0 (true) if the given canonical use-case name is vind-disabled.
use_case_vind_disabled() {
  local name="$1"
  while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]] && continue
    [[ "$line" == "$name" ]] && return 0
  done < <(vind_disabled_use_cases)
  return 1
}

known_use_case_entries() {
  cat <<'EOF'
argocd-in-vcluster|argoCdInVcluster
auto-nodes|autoNodes
auto-snapshots|autoSnapshots
connected-host-cluster|connectedHostCluster
crossplane|crossplane
eso|eso
flux|flux
kyverno|kyverno
database-connector|databaseConnector
namespace-sync|namespaceSync
private-nodes|privateNodes
postgres|postgres
rancher|rancher
resolve-dns|resolveDNS
tenant-observability|tenantObservability
virtual-scheduler|virtualScheduler
vnode|vnode
EOF
}

trim_use_case_token() {
  printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

canonical_use_case_name() {
  case "$1" in
    argocd-in-vcluster|argocdinvcluster|argoCdInVcluster)
      printf '%s\n' "argocd-in-vcluster"
      ;;
    auto-nodes|autonodes|autoNodes)
      printf '%s\n' "auto-nodes"
      ;;
    auto-snapshots|autosnapshots|autoSnapshots)
      printf '%s\n' "auto-snapshots"
      ;;
    connected-host-cluster|connectedhostcluster|connectedHostCluster)
      printf '%s\n' "connected-host-cluster"
      ;;
    crossplane)
      printf '%s\n' "crossplane"
      ;;
    eso)
      printf '%s\n' "eso"
      ;;
    flux)
      printf '%s\n' "flux"
      ;;
    kyverno)
      printf '%s\n' "kyverno"
      ;;
    database-connector|databaseconnector|databaseConnector|cnpg)
      printf '%s\n' "database-connector"
      ;;
    namespace-sync|namespacesync|namespaceSync)
      printf '%s\n' "namespace-sync"
      ;;
    private-nodes|privatenodes|privateNodes)
      printf '%s\n' "private-nodes"
      ;;
    postgres)
      printf '%s\n' "postgres"
      ;;
    rancher)
      printf '%s\n' "rancher"
      ;;
    resolve-dns|resolvedns|resolveDNS)
      printf '%s\n' "resolve-dns"
      ;;
    tenant-observability|tenantobservability|tenantObservability)
      printf '%s\n' "tenant-observability"
      ;;
    virtual-scheduler|virtualscheduler|virtualScheduler)
      printf '%s\n' "virtual-scheduler"
      ;;
    vnode)
      printf '%s\n' "vnode"
      ;;
    *)
      return 1
      ;;
  esac
}

label_key_for_use_case() {
  case "$1" in
    argocd-in-vcluster) printf '%s\n' "argoCdInVcluster" ;;
    auto-nodes) printf '%s\n' "autoNodes" ;;
    auto-snapshots) printf '%s\n' "autoSnapshots" ;;
    connected-host-cluster) printf '%s\n' "connectedHostCluster" ;;
    crossplane) printf '%s\n' "crossplane" ;;
    eso) printf '%s\n' "eso" ;;
    flux) printf '%s\n' "flux" ;;
    kyverno) printf '%s\n' "kyverno" ;;
    database-connector) printf '%s\n' "databaseConnector" ;;
    namespace-sync) printf '%s\n' "namespaceSync" ;;
    private-nodes) printf '%s\n' "privateNodes" ;;
    postgres) printf '%s\n' "postgres" ;;
    rancher) printf '%s\n' "rancher" ;;
    resolve-dns) printf '%s\n' "resolveDNS" ;;
    tenant-observability) printf '%s\n' "tenantObservability" ;;
    virtual-scheduler) printf '%s\n' "virtualScheduler" ;;
    vnode) printf '%s\n' "vnode" ;;
    *)
      return 1
      ;;
  esac
}

use_case_list_contains() {
  local list="$1"
  local item="$2"

  case "
$list
" in
    *"
$item
"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

add_use_case_to_list() {
  local list="$1"
  local item="$2"

  if use_case_list_contains "$list" "$item"; then
    printf '%s' "$list"
  elif [[ -z "$list" ]]; then
    printf '%s' "$item"
  else
    printf '%s\n%s' "$list" "$item"
  fi
}

remove_use_case_from_list() {
  local list="$1"
  local item="$2"
  local result=""
  local current=""

  while IFS= read -r current; do
    [[ -z "$current" ]] && continue
    [[ "$current" == "$item" ]] && continue
    if [[ -z "$result" ]]; then
      result="$current"
    else
      result="${result}
${current}"
    fi
  done <<EOF
$list
EOF

  printf '%s' "$result"
}

resolve_use_case_selection() {
  local spec="$1"
  local enabled=""
  local raw_token=""
  local token=""
  local canonical=""
  local disable="false"
  local defaults_item=""
  local entry=""
  local use_case=""

  if [[ -z "$spec" ]]; then
    spec="$DEFAULT_USE_CASE_SPEC"
  fi

  IFS=',' read -r -a use_case_tokens <<< "$spec"
  for raw_token in "${use_case_tokens[@]}"; do
    token="$(trim_use_case_token "$raw_token")"
    [[ -z "$token" ]] && continue

    disable="false"
    if [[ "$token" == -* ]]; then
      disable="true"
      token="${token#-}"
    fi

    case "$token" in
      default)
        IFS=',' read -r -a default_tokens <<< "$DEFAULT_USE_CASES"
        for defaults_item in "${default_tokens[@]}"; do
          defaults_item="$(trim_use_case_token "$defaults_item")"
          [[ -z "$defaults_item" ]] && continue
          if [[ "$disable" == "true" ]]; then
            enabled="$(remove_use_case_from_list "$enabled" "$defaults_item")"
          else
            enabled="$(add_use_case_to_list "$enabled" "$defaults_item")"
          fi
        done
        ;;
      all)
        while IFS='|' read -r use_case _; do
          [[ -z "$use_case" ]] && continue
          if [[ "$disable" == "true" ]]; then
            enabled="$(remove_use_case_from_list "$enabled" "$use_case")"
          else
            enabled="$(add_use_case_to_list "$enabled" "$use_case")"
          fi
        done <<EOF
$(known_use_case_entries)
EOF
        ;;
      none)
        enabled=""
        ;;
      *)
        if ! canonical="$(canonical_use_case_name "$token")"; then
          echo "[ERROR] Unknown use case: $token" >&2
          echo "[ERROR] Run with --list-use-cases to see the supported names." >&2
          return 1
        fi
        if [[ "$disable" == "true" ]]; then
          enabled="$(remove_use_case_from_list "$enabled" "$canonical")"
        else
          enabled="$(add_use_case_to_list "$enabled" "$canonical")"
        fi
        ;;
    esac
  done

  printf '%s' "$enabled"
}

render_cluster_local_use_case_labels() {
  local spec="$1"
  local indent="${2:-}"
  local enabled=""
  local use_case=""
  local label_key=""
  local value=""

  enabled="$(resolve_use_case_selection "$spec")" || return 1

  while IFS='|' read -r use_case label_key; do
    [[ -z "$use_case" ]] && continue
    value="false"
    if use_case_list_contains "$enabled" "$use_case"; then
      value="true"
    fi
    printf '%s%s: "%s"\n' "$indent" "$label_key" "$value"
  done <<EOF
$(known_use_case_entries)
EOF
}

selected_use_cases_csv() {
  local spec="$1"
  local enabled=""

  enabled="$(resolve_use_case_selection "$spec")" || return 1
  if [[ -z "$enabled" ]]; then
    printf '%s\n' "none"
  else
    printf '%s\n' "$enabled" | paste -sd, -
  fi
}

print_known_use_cases() {
  cat <<'EOF'
Supported use cases for the vind cluster-local secret:

- argocd-in-vcluster
- auto-nodes
- auto-snapshots
- connected-host-cluster
- crossplane
- eso
- flux
- kyverno
- database-connector
- namespace-sync
- postgres
- rancher
- resolve-dns
- virtual-scheduler
- vnode

Selection syntax:

- default
  enables the default self-contained set: eso
- all
  enables every supported use case label
- none
  disables every supported use case label
- comma-separated names
  example: eso,auto-snapshots,flux
- disable with a leading -
  example: all,-crossplane,-rancher
EOF
}

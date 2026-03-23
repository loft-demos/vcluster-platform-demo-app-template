#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Inspect host Docker usage and the current vind cluster's storage posture.

This helper is read-only. It prints:
- host Docker disk usage
- Kubernetes node status and taints
- filesystem usage inside the vind control-plane and worker containers

Usage:
  bash vind-demo-cluster/check-vind-storage.sh

  bash vind-demo-cluster/check-vind-storage.sh \
    --cluster-name team-a \
    --context vcluster-docker_team-a

Options:
  --cluster-name NAME  Optional. Defaults to vcp.
  --context NAME       Optional. Defaults to vcluster-docker_<cluster-name>.
  --help               Show this message.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd" >&2
    exit 1
  fi
}

section() {
  printf '\n## %s\n' "$1"
}

CLUSTER_NAME="vcp"
KUBECTL_CONTEXT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster-name)
      CLUSTER_NAME="${2:-}"
      shift 2
      ;;
    --context)
      KUBECTL_CONTEXT="${2:-}"
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

require_cmd docker

if [[ -z "$KUBECTL_CONTEXT" ]]; then
  KUBECTL_CONTEXT="vcluster-docker_${CLUSTER_NAME}"
fi

section "Host Docker Usage"
docker system df || true

if command -v kubectl >/dev/null 2>&1; then
  section "Kubernetes Nodes"
  if kubectl config get-contexts "$KUBECTL_CONTEXT" >/dev/null 2>&1; then
    kubectl --context "$KUBECTL_CONTEXT" get nodes -o wide || true
    printf '\n'
    kubectl --context "$KUBECTL_CONTEXT" get nodes \
      -o jsonpath='{range .items[*]}{.metadata.name}{" taints="}{range .spec.taints[*]}{.key}{":"}{.effect}{" "}{end}{"\n"}{end}' || true
  else
    echo "[WARN] kubectl context not found: $KUBECTL_CONTEXT" >&2
  fi
fi

section "vind Container Filesystems"
control_plane_container="vcluster.cp.${CLUSTER_NAME}"
if docker ps -a --format '{{.Names}}' | grep -qx "$control_plane_container"; then
  printf '\n[%s]\n' "$control_plane_container"
  docker exec "$control_plane_container" df -h / /var || true
  docker inspect --format 'backing /var volume: {{range .Mounts}}{{if eq .Destination "/var"}}{{.Name}} -> {{.Source}}{{end}}{{end}}' "$control_plane_container" || true
else
  echo "[WARN] Control-plane container not found: $control_plane_container" >&2
fi

worker_containers=()
while IFS= read -r worker_container; do
  [[ -n "$worker_container" ]] || continue
  worker_containers+=("$worker_container")
done < <(docker ps -a --format '{{.Names}}' | grep "^vcluster.node.${CLUSTER_NAME}\." || true)

if [[ "${#worker_containers[@]}" -eq 0 ]]; then
  echo "[WARN] No worker containers found for cluster: $CLUSTER_NAME" >&2
else
  for worker_container in "${worker_containers[@]}"; do
    printf '\n[%s]\n' "$worker_container"
    docker exec "$worker_container" df -h / /var || true
    docker inspect --format 'backing /var volume: {{range .Mounts}}{{if eq .Destination "/var"}}{{.Name}} -> {{.Source}}{{end}}{{end}}' "$worker_container" || true
  done
fi

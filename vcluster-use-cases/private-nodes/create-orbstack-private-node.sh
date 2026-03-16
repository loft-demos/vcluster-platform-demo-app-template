#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Create or start an OrbStack VM for the manual Private Nodes demo flow.

This helper does not try to replace the vCluster Private Nodes connect command.
It only prepares an Ubuntu 24.04 OrbStack VM and can optionally run the
Platform-generated connect command inside that VM.

Usage:
  bash vcluster-use-cases/private-nodes/create-orbstack-private-node.sh

  bash vcluster-use-cases/private-nodes/create-orbstack-private-node.sh \
    --machine private-node-a \
    --connect-command '<paste the connect command from vCluster Platform>'

Options:
  --machine NAME          Optional. Defaults to private-node-1.
  --image DISTRO:VERSION  Optional. Defaults to ubuntu:24.04.
  --arch ARCH             Optional. Defaults to arm64 on Apple Silicon and
                          amd64 on Intel.
  --user NAME             Optional. Defaults to your macOS username.
  --connect-command CMD   Optional. Runs the provided connect command inside
                          the VM as root after the machine is ready.
  --help                  Show this message.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd" >&2
    exit 1
  fi
}

MACHINE_NAME="private-node-1"
IMAGE="ubuntu:24.04"
USER_NAME="${USER:-}"
CONNECT_COMMAND=""

case "$(uname -m)" in
  arm64|aarch64) ARCH="arm64" ;;
  *) ARCH="amd64" ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --machine)
      MACHINE_NAME="${2:-}"
      shift 2
      ;;
    --image)
      IMAGE="${2:-}"
      shift 2
      ;;
    --arch)
      ARCH="${2:-}"
      shift 2
      ;;
    --user)
      USER_NAME="${2:-}"
      shift 2
      ;;
    --connect-command)
      CONNECT_COMMAND="${2:-}"
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

require_cmd orb

if [[ -z "$USER_NAME" ]]; then
  echo "[ERROR] Could not determine the default OrbStack username." >&2
  echo "[ERROR] Pass it explicitly with --user." >&2
  exit 1
fi

if orb list -q | grep -Fx "$MACHINE_NAME" >/dev/null 2>&1; then
  echo "[INFO] OrbStack machine already exists: $MACHINE_NAME"
  orb start "$MACHINE_NAME" >/dev/null
else
  echo "[INFO] Creating OrbStack machine $MACHINE_NAME from $IMAGE ($ARCH)"
  orb create -a "$ARCH" -u "$USER_NAME" "$IMAGE" "$MACHINE_NAME"
fi

echo "[INFO] OrbStack machine details:"
orb info "$MACHINE_NAME"

if [[ -n "$CONNECT_COMMAND" ]]; then
  echo "[INFO] Running the supplied Private Nodes connect command in $MACHINE_NAME"
  orb -m "$MACHINE_NAME" -u root sh -lc "$CONNECT_COMMAND"
fi

cat <<EOF

[INFO] OrbStack private node VM is ready.

Recommended next steps:
1. Create or open a vCluster from the private-node template:
   - vcluster-use-cases/private-nodes/manifests/private-node-template.yaml
2. In vCluster Platform, open the vCluster and copy the Private Nodes connect command.
3. Run it inside the OrbStack VM:
   orb -m $MACHINE_NAME -u root sh -lc '<connect-command>'

Notes:
- This template enables the vCluster VPN, so the join flow does not depend on a
  public control-plane endpoint.
- This helper intentionally does not use cloud-init; the Private Nodes connect
  command handles the node bootstrap.

EOF

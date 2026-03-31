#!/usr/bin/env bash

set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"

APP_NAMESPACE="${APP_NAMESPACE:-argocd}"
APP_NAME="${APP_NAME:-guestbook-pre-prod}"
VCI_NAMESPACE="${VCI_NAMESPACE:-p-default}"
VCI_NAME="${VCI_NAME:-pre-prod-gate-pre-prod}"
NOTIFICATIONS_NAMESPACE="${NOTIFICATIONS_NAMESPACE:-argocd}"
NOTIFICATIONS_CONFIGMAP="${NOTIFICATIONS_CONFIGMAP:-argocd-notifications-cm}"
WAIT_SECONDS="${WAIT_SECONDS:-180}"
POLL_SECONDS="${POLL_SECONDS:-2}"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/test-pre-prod-wakeup.sh status
  bash scripts/test-pre-prod-wakeup.sh force-sleep
  bash scripts/test-pre-prod-wakeup.sh clear-force-sleep
  bash scripts/test-pre-prod-wakeup.sh trigger-sync
  bash scripts/test-pre-prod-wakeup.sh watch
  bash scripts/test-pre-prod-wakeup.sh scenario

Environment overrides:
  APP_NAMESPACE
  APP_NAME
  VCI_NAMESPACE
  VCI_NAME
  WAIT_SECONDS
  POLL_SECONDS
  KUBECTL

What "scenario" does:
  1. Forces the target VCI to sleep
  2. Starts log tails for notifications + wakeup proxy
  3. Triggers a manual Argo CD sync on the target Application
  4. Polls app + VCI status until timeout

Notes:
  - The wake-up path is considered proven once the proxy logs a wake request and
    the VCI transitions away from Sleeping.
  - A 403 from the proxy's cluster-secret patch is a separate follow-up issue;
    it does not mean the wake request itself failed.
EOF
}

jsonpath() {
  local resource="$1"
  local namespace="$2"
  local name="$3"
  local path="$4"
  "$KUBECTL" get "$resource" -n "$namespace" "$name" -o "jsonpath=${path}"
}

app_snapshot() {
  local sync health phase message image revision
  sync="$(jsonpath application "$APP_NAMESPACE" "$APP_NAME" '{.status.sync.status}')"
  health="$(jsonpath application "$APP_NAMESPACE" "$APP_NAME" '{.status.health.status}')"
  phase="$(jsonpath application "$APP_NAMESPACE" "$APP_NAME" '{.status.operationState.phase}')"
  message="$(jsonpath application "$APP_NAMESPACE" "$APP_NAME" '{.status.operationState.message}')"
  image="$(jsonpath application "$APP_NAMESPACE" "$APP_NAME" '{.status.summary.images[*]}')"
  revision="$(jsonpath application "$APP_NAMESPACE" "$APP_NAME" '{.status.operationState.syncResult.revision}')"
  printf 'app sync=%s health=%s op=%s image=%s revision=%s message=%s\n' \
    "${sync:-<none>}" "${health:-<none>}" "${phase:-<none>}" \
    "${image:-<none>}" "${revision:-<none>}" "${message:-<none>}"
}

vci_snapshot() {
  local phase ready_reason force
  phase="$(jsonpath virtualclusterinstance "$VCI_NAMESPACE" "$VCI_NAME" '{.status.phase}')"
  ready_reason="$(jsonpath virtualclusterinstance "$VCI_NAMESPACE" "$VCI_NAME" '{.status.conditions[?(@.type=="Ready")].reason}')"
  force="$(jsonpath virtualclusterinstance "$VCI_NAMESPACE" "$VCI_NAME" '{.metadata.annotations.sleepmode\.loft\.sh/force}')"
  printf 'vci phase=%s ready-reason=%s force=%s\n' \
    "${phase:-<none>}" "${ready_reason:-<none>}" "${force:-<none>}"
}

show_trigger() {
  echo "trigger.wakeup-vcluster:"
  jsonpath configmap "$NOTIFICATIONS_NAMESPACE" "$NOTIFICATIONS_CONFIGMAP" '{.data.trigger\.wakeup-vcluster}'
  echo
}

status_cmd() {
  show_trigger
  app_snapshot
  vci_snapshot
}

force_sleep_cmd() {
  echo "Forcing ${VCI_NAMESPACE}/${VCI_NAME} to sleep..."
  "$KUBECTL" patch virtualclusterinstance -n "$VCI_NAMESPACE" "$VCI_NAME" \
    --type merge \
    -p '{"metadata":{"annotations":{"sleepmode.loft.sh/force":"true"}}}' >/dev/null
  wait_for_phase "Sleeping"
}

clear_force_sleep_cmd() {
  echo "Clearing sleepmode.loft.sh/force from ${VCI_NAMESPACE}/${VCI_NAME}..."
  "$KUBECTL" annotate virtualclusterinstance -n "$VCI_NAMESPACE" "$VCI_NAME" \
    sleepmode.loft.sh/force- >/dev/null 2>&1 || true
  vci_snapshot
}

trigger_sync_cmd() {
  echo "Triggering manual sync for ${APP_NAMESPACE}/${APP_NAME}..."
  "$KUBECTL" patch application -n "$APP_NAMESPACE" "$APP_NAME" \
    --type merge \
    -p '{"operation":{"sync":{"syncOptions":["CreateNamespace=true"]}}}' >/dev/null
  app_snapshot
}

wait_for_phase() {
  local desired="$1"
  local deadline now phase
  deadline=$((SECONDS + WAIT_SECONDS))
  while :; do
    phase="$(jsonpath virtualclusterinstance "$VCI_NAMESPACE" "$VCI_NAME" '{.status.phase}')"
    if [[ "$phase" == "$desired" ]]; then
      vci_snapshot
      return 0
    fi
    now=$SECONDS
    if (( now >= deadline )); then
      echo "Timed out waiting for VCI phase=${desired}" >&2
      vci_snapshot >&2
      return 1
    fi
    sleep "$POLL_SECONDS"
  done
}

watch_cmd() {
  local notif_pid proxy_pid status_pid
  trap 'kill "${notif_pid:-0}" "${proxy_pid:-0}" "${status_pid:-0}" >/dev/null 2>&1 || true' EXIT INT TERM

  "$KUBECTL" logs -n "$NOTIFICATIONS_NAMESPACE" deploy/argocd-notifications-controller \
    -f --since=2m \
    | rg --line-buffered "${APP_NAME}|wakeup-vcluster|invalidated cache" \
    | sed 's/^/[notif] /' &
  notif_pid=$!

  "$KUBECTL" logs -n argocd deploy/vcluster-wakeup-proxy -f --since=2m \
    | sed 's/^/[proxy] /' &
  proxy_pid=$!

  (
    local last_app="" last_vci="" app_line="" vci_line=""
    while :; do
      app_line="$(app_snapshot 2>/dev/null || true)"
      vci_line="$(vci_snapshot 2>/dev/null || true)"
      if [[ "$app_line" != "$last_app" ]]; then
        echo "[status] ${app_line}"
        last_app="$app_line"
      fi
      if [[ "$vci_line" != "$last_vci" ]]; then
        echo "[status] ${vci_line}"
        last_vci="$vci_line"
      fi
      sleep "$POLL_SECONDS"
    done
  ) &
  status_pid=$!

  wait
}

scenario_cmd() {
  echo "Starting pre-prod wake-up scenario test"
  status_cmd
  force_sleep_cmd

  watch_cmd &
  local watch_pid=$!
  trap 'kill "${watch_pid:-0}" >/dev/null 2>&1 || true' EXIT INT TERM

  sleep 3
  trigger_sync_cmd

  local deadline phase op sync
  deadline=$((SECONDS + WAIT_SECONDS))
  while :; do
    phase="$(jsonpath virtualclusterinstance "$VCI_NAMESPACE" "$VCI_NAME" '{.status.phase}')"
    op="$(jsonpath application "$APP_NAMESPACE" "$APP_NAME" '{.status.operationState.phase}')"
    sync="$(jsonpath application "$APP_NAMESPACE" "$APP_NAME" '{.status.sync.status}')"

    if [[ "$phase" != "Sleeping" && "$op" == "Succeeded" && "$sync" == "Synced" ]]; then
      echo
      echo "Scenario completed: VCI woke and app sync succeeded."
      status_cmd
      return 0
    fi

    if (( SECONDS >= deadline )); then
      echo
      echo "Scenario timed out before the app recovered."
      status_cmd
      return 1
    fi

    sleep "$POLL_SECONDS"
  done
}

cmd="${1:-}"
case "$cmd" in
  status)
    status_cmd
    ;;
  force-sleep)
    force_sleep_cmd
    ;;
  clear-force-sleep)
    clear_force_sleep_cmd
    ;;
  trigger-sync)
    trigger_sync_cmd
    ;;
  watch)
    watch_cmd
    ;;
  scenario)
    scenario_cmd
    ;;
  *)
    usage
    exit 1
    ;;
esac

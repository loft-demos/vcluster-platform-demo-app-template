# Sleeping Imported vClusters with Host Argo CD

This directory contains the shared host-side Argo CD plumbing for imported vCluster instances that are allowed to sleep. The current integration is watcher-first and is built around [`vcluster-gitops-watcher`](https://github.com/loft-demos/vcluster-gitops-watcher/blob/main/README.md).

This stack is only about a host Argo CD instance managing imported destinations. If Argo CD is installed inside the vCluster itself, that Argo instance is not the thing waking the vCluster from outside, so this shared host-side flow is not the relevant concern for that use case.

## Prerequisite

The host Argo CD instance must be `v3.4.0-rc1` or newer.

This repo now relies on the Argo CD controller honoring `argocd.argoproj.io/skip-reconcile: "true"` on imported cluster Secrets for a specific destination cluster. In the `vind` path, the host Argo chart is pinned to `v3.4.0-rc1` in [`../../vind-demo-cluster/vcluster.yaml`](../../vind-demo-cluster/vcluster.yaml).

## What Gets Installed

The stack is bootstrapped by [`../app-of-apps/vcluster-sleep-wakeup-app.yaml`](../app-of-apps/vcluster-sleep-wakeup-app.yaml).

The concrete manifests live under [`base/`](./base/), with a `local-contained` overlay under [`overlays/local-contained/`](./overlays/local-contained/).

The shared stack installs:

- `argocd-notifications-cm`
- `argocd-notifications-secret`
- `vcluster-gitops-watcher`

The notifications ConfigMap and Secret stay in place for GitHub PR comment/status notifications. They are no longer part of the wake-up path.

## What Changed

This repo no longer uses:

- Argo CD Notifications webhook triggers for waking sleeping vClusters
- `vcluster-wakeup-proxy`
- Kargo `http` promotion steps that call the proxy
- `sleepmode.loft.sh/ignore-user-agents: argo*` as the main sleep-mode control

Instead, the watcher directly observes:

- `VirtualClusterInstance` state
- host Argo CD `Application` objects
- active Kargo `Promotion` objects when Kargo is installed

## Watcher Flow

At a high level, the shared flow is now:

1. A sleeping imported vCluster is represented by a `VirtualClusterInstance` and an imported Argo CD cluster Secret such as `loft-<project>-vcluster-<virtualcluster>`.
2. If Kargo is installed, the watcher sees an active `Promotion` for a Stage that ends with `argocd-update` and treats that as the earliest wake signal.
3. If Kargo is not involved, the watcher falls back to Argo-only sync intent by watching `Application.operation.sync`.
4. The watcher sends the wake request directly to the platform API.
5. While the destination is sleeping or waking, the watcher patches the imported cluster Secret with `argocd.argoproj.io/skip-reconcile: "true"`.
6. When the `VirtualClusterInstance` becomes ready, the watcher removes `skip-reconcile` and hard-refreshes the affected Argo CD apps.

The result is:

- Kargo can wake sleeping destinations without extra `http` steps
- host Argo sync intent can still wake non-Kargo apps
- Argo CD does not keep thrashing a sleeping or half-ready destination

## Repo Configuration

In this repo, the watcher is configured to:

- watch `VirtualClusterInstance` resources from the management API
- read Kargo `Promotion` objects so it can wake from active `argocd-update` promotions
- patch imported cluster Secrets and matching Argo CD apps in `argocd`
- call the platform API directly at `http://loft.vcluster-platform.svc.cluster.local`
- read the wake bearer token from the `accessKey` entry in `argocd-notifications-secret`

See:

- [`base/vcluster-gitops-watcher.yaml`](./base/vcluster-gitops-watcher.yaml)
- [`base/argocd-notifications-cm.yaml`](./base/argocd-notifications-cm.yaml)
- [`base/argocd-notifications-secret.yaml`](./base/argocd-notifications-secret.yaml)

## About `skip-reconcile`

`argocd.argoproj.io/skip-reconcile: "true"` is now the main host-Argo control.

The watcher uses it as a temporary pause while the destination is sleeping or waking, then removes it when the vCluster is ready again. Do not leave `skip-reconcile` set permanently unless you intentionally want Argo CD to stop reconciling apps that target that cluster.

## Kargo Caveat

The watcher fixes the wake-up and Argo handoff path, but it does not redefine Kargo verification semantics.

If a destination vCluster goes to sleep while a Kargo verification is still in progress, that verification can still fail. In practice, sleep should be treated as safe only after the Stage has returned to `Ready=True` / `Healthy=True`, unless you intentionally plan to override the failed verification.

## App Metadata

Wake-up no longer depends on:

- `notifications.argoproj.io/subscribe.wakeup-vcluster.vcluster-platform`
- `metadata.labels.vclusterProjectId`
- `metadata.labels.vclusterName`

Those labels may still appear on some PR preview apps because the GitHub notification templates use them to render useful links, but they are no longer required for waking sleeping destinations.

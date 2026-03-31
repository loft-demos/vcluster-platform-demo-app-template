# Shared vCluster Sleep Wake-Up

This directory contains the shared host-side Argo CD resources that make
sleeping imported vCluster instances behave well when they are added to Argo CD and use
`sleepmode.loft.sh/ignore-user-agents: argo*`.

## Intent

The main goal is to let Argo CD manage imported vCluster instances without keeping them
awake all the time.

Argo CD has more than one kind of background activity, and they do not all mean
the same thing. The important distinction for sleepy imported clusters is:

- source polling: Git or Helm polling to discover desired-state changes
- cluster cache and cluster-info traffic: controller traffic to maintain its
  view of a registered destination cluster
- application reconciliation: status comparison, health evaluation, and sync
  behavior for Applications that target that cluster

According to the Argo CD docs:

- Git and Helm repositories are polled roughly every 3 minutes by default
  (`timeout.reconciliation` plus jitter); see the
  [Argo CD FAQ](https://argo-cd.readthedocs.io/en/stable/faq/)
- the application controller uses Kubernetes watch APIs to maintain cluster
  cache and updates cluster information every 10 seconds by default; see the
  [Argo CD HA docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/)
- a cluster Secret annotation
  `argocd.argoproj.io/skip-reconcile=true` makes the controller skip
  reconciliation for apps targeting that cluster; see
  [Cluster Management](https://argo-cd.readthedocs.io/en/release-3.4/operator-manual/cluster-management/)

For sleep mode, the main problem is not Git polling. The main problem is
cluster-directed controller traffic, because that traffic can reach the sleepy
vCluster API often enough to keep waking it back up.

To preserve the value of sleep mode, these templates commonly add:

```yaml
sleepmode.loft.sh/ignore-user-agents: argo*
```

That prevents routine Argo CD polling from waking the vCluster, but it also means
Argo CD now needs a deliberate wake-up path when a real sync or deployment should
happen. This shared stack provides that path.

Operationally, we treat sleepy imported clusters as needing this protection as
soon as they are added to Argo CD, not only after a specific Application starts
targeting them.

This is shared host-side plumbing because the problem is not specific to one
demo. Any vCluster that is:

- imported into Argo CD
- configured to use sleep mode
- configured to ignore `argo*` user agents

should typically use this same stack in the host Argo CD instance.

## What Gets Installed

The stack is bootstrapped by
[`../app-of-apps/vcluster-sleep-wakeup-app.yaml`](../app-of-apps/vcluster-sleep-wakeup-app.yaml).

The concrete manifests live under [`base/`](./base/), with a `local-contained`
overlay under [`overlays/local-contained/`](./overlays/local-contained/).

The shared stack installs:

- `argocd-notifications-cm` with the `wakeup-vcluster` webhook trigger
- `argocd-notifications-secret` as the label-backed Secret reference used by
  Argo CD Notifications
- `vcluster-wakeup-proxy`
- `vcluster-wakeup-watcher`

## How The Flow Works

At a high level, the flow looks like this:

1. A sleeping imported vCluster is intentionally ignoring normal `argo*`
   requests.
2. A real deployment event happens, such as an `Application` becoming
   `OutOfSync`, or Argo ending up in a stale `Synced` / `Unknown` state because
   the destination API is asleep.
3. Argo CD Notifications sends a webhook to `vcluster-wakeup-proxy`.
4. The proxy forwards the wake-triggering `POST` to the vCluster Platform API
   path for the target `VirtualClusterInstance`.
5. Once the vCluster begins waking, the watcher keeps Argo from repeatedly
   reconciling against a destination that is still sleeping or only partially
   ready.
6. When the `VirtualClusterInstance` becomes ready again, the watcher removes
   the pause behavior and nudges Argo to refresh and resume normal work.

The result is:

- routine Argo cluster traffic does not keep the vCluster online
- real sync activity can still wake the vCluster on demand
- Argo behaves more cleanly while the destination transitions through sleeping
  and waking states

## Why `ignore-user-agents` And `skip-reconcile` Both Matter

These two controls complement each other, but they are not interchangeable.

`sleepmode.loft.sh/ignore-user-agents: argo*` is the vCluster-side protection.
It prevents routine Argo-originated API traffic from waking the sleeping
vCluster in the first place.

`argocd.argoproj.io/skip-reconcile: "true"` on the imported cluster Secret is
the Argo-side pause switch. It tells Argo CD to skip reconciliation for apps
that target that cluster while the destination is sleeping or waking.

That annotation is very relevant here, but it solves a different problem than
`ignore-user-agents`.

What the Argo CD docs clearly say is:

- `skip-reconcile` makes the controller skip reconciliation for apps targeting
  that cluster

What the docs do not clearly say is:

- that `skip-reconcile` stops all cluster-directed controller traffic
- that it slows or disables cluster-info refresh for a merely registered
  cluster

In other words:

- `ignore-user-agents` reduces accidental wake-ups caused by routine Argo
  cluster traffic
- `skip-reconcile` reduces noisy or premature app behavior while the cluster is
  intentionally unavailable

The watcher uses `skip-reconcile` as a temporary control while the VCI is
sleeping or waking, and then removes it once the VCI is ready again. If you
leave `skip-reconcile` on permanently, Argo CD will not reconcile apps that
target that cluster.

We do not treat `skip-reconcile` as a full replacement for
`ignore-user-agents`, because the two settings operate at different layers and
solve different problems.

One nuance: for a cluster that is merely registered in Argo CD but has no apps
targeting it yet, the docs do not clearly guarantee what `skip-reconcile`
suppresses beyond app reconciliation. Because of that, we do not rely on the
cluster Secret annotation alone as a substitute for `ignore-user-agents`.

## How `vcluster-wakeup-proxy` Works

`vcluster-wakeup-proxy` handles the wake-triggering HTTP request.

Its job is to sit in front of the vCluster Platform upstream and make the first
wake request behave like an accepted action instead of a hard failure when the
target is still waking up.

In this repo's configuration, the proxy:

- receives the Argo CD Notifications webhook in the `argocd` namespace
- forwards the request to `UPSTREAM_BASE`
- treats transient wake-time upstream responses such as `502` and `504` as
  accepted for the wake path
- patches the imported Argo CD cluster Secret using the template
  `loft-{project}-vcluster-{virtualcluster}` so Argo refreshes its destination
  cluster cache sooner

Why that matters:

- the first wake request often reaches the platform before the destination API
  is ready to answer cleanly
- Argo should treat that as "wake initiated" instead of "deployment failed"
- refreshing the imported cluster Secret helps Argo notice the destination is
  usable again faster

The proxy is useful for Argo CD Notifications and for other callers too. In
this repo, Kargo promotion steps can also call the same proxy before an
`argocd-update`.

## How `vcluster-wakeup-watcher` Works

`vcluster-wakeup-watcher` continuously reconciles Argo CD behavior from
`VirtualClusterInstance` state.

It polls `VirtualClusterInstance` resources from the management cluster API and
derives the corresponding imported Argo CD cluster Secret and matching
`Application` objects.

Its job is not to send the initial wake request. Instead, it keeps Argo CD's
behavior sane while a destination is sleeping, waking, or ready again.

In this repo's configuration, the watcher:

- watches `VirtualClusterInstance` state from the management API
- maps each VCI to the imported Argo CD cluster Secret name template
  `loft-{project}-vcluster-{virtualcluster}`
- marks the imported cluster Secret with
  `argocd.argoproj.io/skip-reconcile: "true"` while a vCluster is sleeping or
  waking
- removes that pause state when the vCluster is ready again
- annotates matching `Application` resources with
  `argocd.argoproj.io/refresh: hard` once the target is ready
- optionally patches visible `Application` health while the vCluster is
  sleeping or waking so the UI better reflects reality

Why that matters:

- without the watcher, Argo can keep retrying a sleeping destination in noisy or
  confusing ways
- a destination that is waking may still not be ready for real sync work yet
- unpausing and refreshing Argo only when the VCI is ready gives a much cleaner
  handoff back to normal reconciliation

## Application Requirements

Applications that should trigger wake-up on demand still need:

- `notifications.argoproj.io/subscribe.wakeup-vcluster.vcluster-platform: ''`
- `metadata.labels.vclusterProjectId`
- `metadata.labels.vclusterName`

Those labels identify the vCluster Platform project and the
`VirtualClusterInstance` name that the shared notification template should wake.

Example:

```yaml
metadata:
  annotations:
    notifications.argoproj.io/subscribe.wakeup-vcluster.vcluster-platform: ''
  labels:
    vclusterProjectId: default
    vclusterName: pre-prod-gate-pre-prod
```

Without those labels, the notification template cannot construct the correct
vCluster Platform wake-up path.

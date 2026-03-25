# Automated Pull Request Environments with vCluster Platform and ArgoCD 

The `pr-environments` examples cover two different approaches for using vCluster Platform and Argo CD to create and deploy to ephemeral Kubernetes virtual clusters for GitHub Pull Requests. In both cases, a `VirtualClusterInstance` custom resource referencing a `VirtualClusterTemplate` resources is used to create a vCluster Platform managed vCluster instance.

The first approach leverages a pre-existing shared Argo CD instance (and only requires one Argo CD instance) that has been integrated with a vCluster Platform project for both creating the PR vCluster and for deploying the PR preview app into the vCluster.

The second approach leverages a pre-existing shared Argo CD instance that has been integrated with a vCluster Platform project for creating the PR vCluster, and installs a second, ephemeral, Argo CD instance into the PR vCluster (using a Virtual Cluster Template App) and the PR preview app is deployed into the vCluster using that embbedded (and completely ephemeral) Argo CD instance.

## Shared Wake-Up Notifications

This use case also contains the shared Argo CD Notifications plumbing that wakes sleeping vCluster instances on demand. The same pieces are reused by the pull request examples and by the continuous-promotion demos.

Why this exists:

- Sleeping vClusters often use `sleepmode.loft.sh/ignore-user-agents: argo*` so normal Argo CD health checks do not constantly wake them up.
- Once Argo's routine polling is ignored, Argo needs a separate way to ask vCluster Platform to wake the target before a sync can complete.

What the shared resources do:

- [manifests/argocd-notifications-cm.yaml](manifests/argocd-notifications-cm.yaml) defines the `wakeup-vcluster` notification trigger and webhook template.
- [manifests/vcluster-wakeup-proxy.yaml](manifests/vcluster-wakeup-proxy.yaml) deploys a small proxy in the `argocd` namespace that receives the notification and forwards the wake-triggering request to vCluster Platform.

How the flow works:

1. An Argo CD `Application` that targets a sleeping vCluster becomes `OutOfSync`.
2. The `wakeup-vcluster` notification trigger fires.
3. Argo CD Notifications renders the webhook path using the app's `vclusterProjectId` and `vclusterName` labels.
4. The request is sent to `vcluster-wakeup-proxy`, which forwards the wake-triggering call to the vCluster Platform path for that VCI.
5. Once the VCI wakes up, Argo CD can continue syncing against the imported cluster destination.

What an app needs to participate:

- `notifications.argoproj.io/subscribe.wakeup-vcluster.vcluster-platform: ''`
- `metadata.labels.vclusterProjectId`
- `metadata.labels.vclusterName`

Without those labels, the notification template cannot build the vCluster Platform path to wake the correct instance.

Example:

```yaml
metadata:
  annotations:
    notifications.argoproj.io/subscribe.wakeup-vcluster.vcluster-platform: ''
  labels:
    vclusterProjectId: default
    vclusterName: pre-prod-gate-pre-prod
```

Those values must identify the vCluster Platform project and the `VirtualClusterInstance` name, not the Argo CD cluster destination name. For example, Argo may target a destination like `loft-default-vcluster-pre-prod-gate-pre-prod`, while the wake-up template still needs `default` and `pre-prod-gate-pre-prod` to construct the vCluster Platform request path.

This same shared wake-up plumbing is also referenced from [../continuous-promotion/README.md](../continuous-promotion/README.md), because the continuous-promotion demos reuse the same notification template and proxy.

## Pros and Cons of the Two Approaches
### 1. Shared Argo CD creates and deplos to ephemeral vCluster:

**✅ Pros**

**✔ Lower Resource Usage** – A single Argo CD instance manages all PR environments, reducing infrastructure costs.

**✔ Faster PR Deployments** – No need to spin up a new Argo CD instance for every PR, making pipelines more efficient.

**✔ Persistent History & Logs** – Debugging is easier since logs and deployment history remain even after a PR is merged or closed.

**✔ Simpler Maintenance** – No need to manage lifecycle automation for ephemeral Argo CD instances.

**❌ Cons**

**✖ Potential Performance Issues** – Multiple PRs sharing the same Argo CD instance could lead to Argo CD performance bottlenecks.

**✖ Security & Multi-Tenancy Issues** – Requires strict RBAC to prevent unauthorized access between PR environments.

**✖ Harder to Test Argo CD Changes** – If a PR modifies Argo CD configurations, testing becomes trickier without impacting the shared instance.

**✖ Possible State Pollution** – If a PR fails to clean up resources, it could leave orphaned vCluster instances in the shared cluster.

### 2. Embedded Argo CD is deployed into and deploys to the ephmeral PR vCluster:
Details of this setup, to include the components used, Kubernetes resources configuration and explanation are available [here](../../crossplane/vcluster-pull-request-environment).

**✅ Pros**

**✔ Full Isolation** – Each PR gets its own vCluster and Argo CD, preventing conflicts.

**✔ Better Security** – No risk of PRs affecting shared Argo CD configurations or external clusters.

**✔ Cleaner State Management** – When the PR is closed, the entire vCluster and Argo CD instance are deleted, avoiding leftover resources.

**✔ Easier Testing of Argo CD Configs** – If Argo CD configuration itself is part of the PR, you can test changes safely.

**✔ No RBAC Headaches** – No need to worry about multi-tenant access control in a shared instance.

**❌ Cons**

**✖ Higher Resource Consumption** – Spinning up a new Argo CD instance per PR requires more CPU/memory.

**✖ Longer PR Setup Time** – Each PR needs to spin up a fresh vCluster + Argo CD, which may slow CI/CD pipelines.

**✖ More Complex Management** – Requires automation to spin up and tear down vCluster and Argo CD per PR efficiently.

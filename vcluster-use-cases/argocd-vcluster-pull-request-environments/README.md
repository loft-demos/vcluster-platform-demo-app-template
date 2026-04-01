# Automated Pull Request Environments with vCluster Platform and Argo CD

The `pr-environments` examples cover two different approaches for using vCluster Platform and Argo CD to create and deploy to ephemeral Kubernetes virtual clusters for GitHub Pull Requests. In both cases, a `VirtualClusterInstance` custom resource referencing a `VirtualClusterTemplate` resources is used to create a vCluster Platform managed vCluster instance.

The first approach leverages a pre-existing shared Argo CD instance (and only requires one Argo CD instance) that has been integrated with a vCluster Platform project for both creating the PR vCluster and for deploying the PR preview app into the vCluster.

The second approach leverages a pre-existing shared Argo CD instance that has been integrated with a vCluster Platform project for creating the PR vCluster, and installs a second, ephemeral, Argo CD instance into the PR vCluster (using a Virtual Cluster Template App) and the PR preview app is deployed into the vCluster using that embbedded (and completely ephemeral) Argo CD instance.

## Shared Host Argo Wake-Up

The shared-host-Argo path now consumes the watcher-first stack documented under
[../../vcluster-gitops/argocd/vcluster-sleep-wakeup/README.md](../../vcluster-gitops/argocd/vcluster-sleep-wakeup/README.md).
That same host-side stack is also reused by the continuous-promotion demos.

What the shared resources do:

- [../../vcluster-gitops/argocd/vcluster-sleep-wakeup/base/kustomization.yaml](../../vcluster-gitops/argocd/vcluster-sleep-wakeup/base/kustomization.yaml) installs the shared `argocd-notifications-cm`, `argocd-notifications-secret`, and `vcluster-gitops-watcher` resources into the host Argo CD instance.
- [../../vcluster-gitops/argocd/app-of-apps/vcluster-sleep-wakeup-app.yaml](../../vcluster-gitops/argocd/app-of-apps/vcluster-sleep-wakeup-app.yaml) bootstraps that shared stack as part of the normal Argo CD app-of-apps flow.
- `vcluster-gitops-watcher` observes `VirtualClusterInstance` state and host Argo CD sync intent, wakes sleeping imported destinations directly through the platform API, then pauses or resumes imported-cluster reconciliation as the destination moves through sleeping, waking, and ready states.

How the shared-host flow works:

1. A PR preview `Application` targets an imported vCluster destination.
2. When Argo CD records sync intent on that app, the shared watcher treats that as the wake signal.
3. The watcher calls the platform API directly for the matching `VirtualClusterInstance`.
4. While the destination is sleeping or waking, the watcher patches the imported cluster Secret with `argocd.argoproj.io/skip-reconcile: "true"`.
5. When the VCI becomes ready again, the watcher removes `skip-reconcile` and hard-refreshes the affected apps.

The shared-host path no longer depends on:

- `notifications.argoproj.io/subscribe.wakeup-vcluster.vcluster-platform`
- a wake-up proxy
- `sleepmode.loft.sh/ignore-user-agents: argo*`

If Argo CD is installed inside the vCluster instead of managing it from the
host, this host-side wake-up concern is different: the embedded Argo instance is
not the thing waking that vCluster from outside. That is why the shared-host
watcher flow is most relevant for the first approach in this README, not the
embedded-Argo approach.

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

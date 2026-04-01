# Continuous Promotion with Kargo

Demonstrates GitOps-native continuous promotion across isolated Kubernetes environments using [Kargo](https://kargo.akuity.io) and Argo CD. Each promotion stage is a real, fully isolated Kubernetes cluster (vCluster), provisioned on demand and visible to Kargo as a first-class Argo CD destination.

## Enable

**vind:**

```bash
bash vind-demo-cluster/bootstrap-self-contained.sh --use-cases continuous-promotion
```

**Managed / self-managed:**

```bash
kubectl -n argocd label secret cluster-local continuousPromotion=true --overwrite
```

**vCP Generator:** add `continuousPromotion` as a boolean parameter in `vcluster-platform-demo-template.yaml`.

Generator-hosted environments typically expose Kargo at `https://kargo-{REPLACE_VCLUSTER_NAME}.{REPLACE_BASE_DOMAIN}` and the dedicated webhook ingress at `https://kargo-webhooks-{REPLACE_VCLUSTER_NAME}.{REPLACE_BASE_DOMAIN}`. The local `vind` path defaults to `https://kargo.{REPLACE_BASE_DOMAIN}` for the UI/API and `https://kargo-webhooks.{REPLACE_BASE_DOMAIN}` for external webhooks unless you override those hosts during template replacement.

## What gets deployed

- **Kargo operator** — installed via Helm into the `kargo` namespace; UI available at the configured Kargo host
- **Argo Rollouts** - leveraged for Kargo stage verification with its `AnalysisTemplate` custom resource
- **Forgejo runner (vind self-contained only)** — shared CI runner in the `forgejo` namespace; builds and pushes the demo app image on every commit to `src/` or `helm-chart/`
- **Progressive Delivery demo** — classic dev → staging → prod pipeline
- **Pre-Prod Gate demo** — pre-prod vCluster → prod pipeline

The default path is for Flux to own the Kargo install and Kargo CR manifests
when the cluster has both `continuousPromotion=true` and `flux=true`. The
legacy Argo CD-managed Kargo path is still available through the
`legacyArgoKargo=true` cluster label.

On the `vind` self-contained path, that legacy label is derived automatically
when you enable `continuous-promotion` without `flux`, so local-contained
bootstraps do not need an extra manual toggle. If you want Flux to own Kargo in
`vind`, enable both use cases together.

On the Flux-owned path, Kargo auth now comes from an ESO-managed
`ExternalSecret` under
[../flux/host-apps/kargo/auth/](../flux/host-apps/kargo/auth/) that renders the
`kargo-auth-values` Secret in `p-vcluster-flux-demo`. Flux now gates the Kargo
install on that `ExternalSecret` becoming Ready, which avoids the earlier
half-installed state where Kargo could come up with missing auth values and
never fully recover after ESO was slow to reconcile.

---

## Sleep Mode And Wake-Up

Continuous-promotion stage vClusters are imported into a shared host Argo CD
instance, so sleep-mode behavior is now handled by the shared
`vcluster-gitops-watcher` stack documented in
[../../vcluster-gitops/argocd/vcluster-sleep-wakeup/README.md](../../vcluster-gitops/argocd/vcluster-sleep-wakeup/README.md).

The important change is that this repo no longer relies on:

- `sleepmode.loft.sh/ignore-user-agents: argo*`
- Argo CD Notifications wake-up triggers
- `vcluster-wakeup-proxy`
- Kargo `http` promotion steps before `argocd-update`

Instead:

1. Kargo promotions end with `argocd-update`.
2. The shared watcher observes active `Promotion` objects and wakes sleeping
   destinations directly before Argo CD finishes creating
   `Application.operation.sync`.
3. While the destination is sleeping or waking, the watcher patches the
   imported cluster Secret with
   `argocd.argoproj.io/skip-reconcile: "true"`.
4. Once the `VirtualClusterInstance` is ready again, the watcher removes that
   pause and hard-refreshes the affected apps.

That means sleeping-stage promotions no longer need per-project wake tokens,
inline wake polling, or app-level wake annotations. The Argo CD Applications in
this demo only need to target the imported cluster normally and keep the
`kargo.akuity.io/authorized-stage` annotation so the watcher can correlate
active Promotions with the right destination.

One important caveat still applies: the watcher fixes wake-up orchestration, but
it does not make an in-flight Kargo verification succeed if the vCluster goes to
sleep mid-verification. Treat sleep as safe only after the Stage has returned to
`Ready=True` / `Healthy=True`, unless you intentionally plan to override the
failed verification.

The shared wake-up stack is now bootstrapped centrally for the host Argo CD instance:

- [../../vcluster-gitops/argocd/vcluster-sleep-wakeup/README.md](../../vcluster-gitops/argocd/vcluster-sleep-wakeup/README.md)
- [../../vcluster-gitops/argocd/app-of-apps/vcluster-sleep-wakeup-app.yaml](../../vcluster-gitops/argocd/app-of-apps/vcluster-sleep-wakeup-app.yaml)

---

## CI / Image pipeline

The demo app image (`{REPO_NAME}-demo-app`) is built and pushed automatically whenever `src/` or `helm-chart/` changes land on `main`.

There are two CI paths in this repo:

- `vind` self-contained uses [../../.forgejo/workflows/build-push.yaml](../../.forgejo/workflows/build-push.yaml) plus the shared Forgejo runner from [../../vind-demo-cluster/forgejo-runner/forgejo-runner.yaml](../../vind-demo-cluster/forgejo-runner/forgejo-runner.yaml)
- GitHub-backed Generator / managed / self-managed flows use the existing GitHub Actions workflows such as [../../.github/workflows/main-build-push.yaml](../../.github/workflows/main-build-push.yaml) on the standard GitHub-hosted runner fleet

In the `vind` self-contained path, the shared Forgejo runner follows Forgejo's Docker-access guidance by exposing an isolated pod-local DinD socket to job containers and exporting `DOCKER_HOST` so workflow steps can reach it.

The demo app image is tagged with the `appVersion` from `helm-chart/Chart.yaml` and pushed to the configured OCI registry. The Kargo Warehouse for both demos watches that image repository and triggers promotion automatically when a new semver tag appears.

On the Flux-owned Kargo path, the host cluster also now carries a cluster-level Kargo GitHub webhook receiver. GHCR cannot send webhooks directly, so GitHub`package` events from the associated source repository are the trigger path.Kargo publishes the receiver URL in `ClusterConfig.status.webhookReceivers`, and when Crossplane is also enabled this repo now auto-applies a`KargoGitHubWebhook` claim so Crossplane creates the matching GitHub webhook from that status URL. That lets new images refresh `Warehouse`s immediately instead of waiting for polling.

The Flux bridge for that Kargo host-app path now also creates its own`GitRepository` (`vcluster-flux-demo-kargo`) in `p-vcluster-flux-demo`. That removes the earlier race where the continuous-promotion Kargo bridge could reconcile before the separate Flux demo source `GitRepository` from the Flux use case existed.

In the `vind` self-contained path, bootstrap also creates a `forgejo-image-credentials` Secret in the `progressive-delivery` and `pre-prod-gate` namespaces so Kargo can authenticate to the private Forgejo registry. GitHub-backed paths only need an equivalent Kargo image-credential secret when the chosen registry is private.

To trigger a new build manually, bump `appVersion` in `helm-chart/Chart.yaml` and push to `main`.

**Key files:**

| File | Purpose |
|---|---|
| [../../.github/workflows/main-build-push.yaml](../../.github/workflows/main-build-push.yaml) | GitHub Actions build/push flow used by Generator and other GitHub-backed environments |
| [.forgejo/workflows/build-push.yaml](/.forgejo/workflows/build-push.yaml) | Forgejo Actions build/push flow used by the `vind` self-contained path |
| [../../vind-demo-cluster/forgejo-runner/forgejo-runner.yaml](../../vind-demo-cluster/forgejo-runner/forgejo-runner.yaml) | Shared vind runner Deployment + DinD sidecar |
| [../../vind-demo-cluster/forgejo-runner/forgejo-runner-config.yaml](../../vind-demo-cluster/forgejo-runner/forgejo-runner-config.yaml) | Runner label mappings used by the daemon |
| [../../vcluster-gitops/overlays/local-contained/forgejo-runner-app.yaml](../../vcluster-gitops/overlays/local-contained/forgejo-runner-app.yaml) | Argo CD Application deploying the shared vind runner |

---

## Demo 1 — Progressive Delivery

```text
Warehouse ({REPO_NAME}-demo-app from configured OCI registry)
    │
    ▼ auto-promote
  dev (pd-dev vCluster)
    │
    ▼ auto-promote + health-check verification
  staging (pd-staging vCluster)
    │
    ▼ manual approval required
  prod (pd-prod vCluster)
```

**Verification:** After promoting to staging, Kargo runs an `AnalysisRun` that curl-checks the app ingress URL. Only on pass does freight become eligible for prod.

**Key files:**

| File | Purpose |
|---|---|
| [manifests/progressive-delivery/namespace.yaml](manifests/progressive-delivery/namespace.yaml) | Pre-creates the `progressive-delivery` namespace with `kargo.akuity.io/project: "true"` so Kargo can adopt it |
| [manifests/progressive-delivery/kargo-project.yaml](manifests/progressive-delivery/kargo-project.yaml) | Kargo Project (adopts the labeled `progressive-delivery` namespace) |
| [manifests/progressive-delivery/kargo-warehouse.yaml](manifests/progressive-delivery/kargo-warehouse.yaml) | Watches `{REPO_NAME}-demo-app` image tags in the configured OCI registry |
| [manifests/progressive-delivery/kargo-stages.yaml](manifests/progressive-delivery/kargo-stages.yaml) | dev, staging, prod Stages that promote with `argocd-update`; the shared watcher wakes sleeping destinations from the active Kargo `Promotion` |
| [../../vcluster-gitops/argocd/vcluster-sleep-wakeup/README.md](../../vcluster-gitops/argocd/vcluster-sleep-wakeup/README.md) | Shared host Argo CD wake-up stack centered on `vcluster-gitops-watcher` |
| [manifests/progressive-delivery/kargo-analysis-template.yaml](manifests/progressive-delivery/kargo-analysis-template.yaml) | curl health-check AnalysisTemplate |
| [manifests/progressive-delivery/kargo-vcluster-template.yaml](manifests/progressive-delivery/kargo-vcluster-template.yaml) | VCT for stage vCluster instances with sleep mode enabled and Argo CD import enabled |
| [manifests/progressive-delivery/kargo-vcluster-instances.yaml](manifests/progressive-delivery/kargo-vcluster-instances.yaml) | pd-dev, pd-staging, pd-prod VCIs |
| [manifests/progressive-delivery/guestbook-apps.yaml](manifests/progressive-delivery/guestbook-apps.yaml) | Stable Argo CD Applications for dev, staging, and prod, each annotated with its authorized Kargo Stage |

---

## Demo 2 — Pre-Prod Gate

Inspired by a real-world pattern: uses a long-lived pre-prod vCluster running on the same underlying hardware as production to test changes before they reach real prod clusters. The vCluster use vCP Sleep Mode to scale to zero between promotions, eliminating idle cost.

### Why?

A Shared Nodes vCluster is an effective pre-production target for Kargo because it enables selective divergence on top of production-parity platform infrastructure, while also supporting low-cost lifecycle testing via sleep/wake.

Instead of recreating a full staging environment, the promoted workload runs in a virtual cluster that inherits the host cluster’s platform stack. Only the application and explicitly chosen components differ. With sleep mode, the same environment can be reused across promotion cycles while also validating real upgrade behavior.

### Core idea

Traditional pre-prod environments often drift from production because they duplicate too much infrastructure and platform software. A Shared Nodes vCluster changes the model:

- The host cluster provides the common platform substrate
- The vCluster provides workload isolation and an independent Kubernetes API surface
- Kargo promotes only the candidate changes into that vCluster
- Argo CD deploys those changes declaratively
- Everything else stays shared unless explicitly overridden

This produces a pre-prod environment that is both:

- closer to production than a standalone staging cluster
- safer than testing directly in production
- reusable across promotion cycles via sleep mode

### Why this is attractive for Kargo

Kargo’s purpose is to answer whether a specific artifact or config change is ready to advance. That works best when the target environment differs from production only in the exact changes being evaluated.

A Shared Nodes vCluster supports that directly:

- promote a new app version into the vCluster
- optionally promote one or two supporting components alongside it
- keep the rest of the platform identical to production

```text
Warehouse ({REPO_NAME}-demo-app from configured OCI registry)
    │
    ▼ auto-promote
  pre-prod (pre-prod-gate-pre-prod vCluster — scales to zero when idle)
    │  └─ 1 minute soak time required
    ▼ manual approval required
  prod (production cluster)
```

**Verification:** A Kubernetes Job runs inside the cluster against the repo-scoped pre-prod ingress URL `https://guestbook-ppg-pre-prod-{REPLACE_REPO_NAME}.{REPLACE_BASE_DOMAIN}`. The job retries for up to 2 minutes to account for vCluster wake-up time after scale-to-zero. New Freight auto-promotes directly into pre-prod; pass = exit 0, fail = exit 1.

**Key files:**

| File | Purpose |
|---|---|
| [manifests/pre-prod-gate/namespace.yaml](manifests/pre-prod-gate/namespace.yaml) | Pre-creates the `pre-prod-gate` namespace with `kargo.akuity.io/project: "true"` so Kargo can adopt it |
| [manifests/pre-prod-gate/kargo-project.yaml](manifests/pre-prod-gate/kargo-project.yaml) | Kargo Project (adopts the labeled `pre-prod-gate` namespace) |
| [manifests/pre-prod-gate/kargo-warehouse.yaml](manifests/pre-prod-gate/kargo-warehouse.yaml) | Watches `{REPO_NAME}-demo-app` image tags in the configured OCI registry |
| [manifests/pre-prod-gate/kargo-stages.yaml](manifests/pre-prod-gate/kargo-stages.yaml) | pre-prod and prod Stages + soak time; the shared watcher wakes the sleeping pre-prod destination from the active `Promotion` |
| [../../vcluster-gitops/argocd/vcluster-sleep-wakeup/README.md](../../vcluster-gitops/argocd/vcluster-sleep-wakeup/README.md) | Shared host Argo CD wake-up stack centered on `vcluster-gitops-watcher` |
| [manifests/pre-prod-gate/shared-demo-cluster-store.yaml](manifests/pre-prod-gate/shared-demo-cluster-store.yaml) | Host-cluster Kubernetes-provider `ClusterSecretStore`, source Secret, and RBAC used by both the shared-node pre-prod vCluster app and the host-cluster prod app |
| [manifests/pre-prod-gate/kargo-analysis-template.yaml](manifests/pre-prod-gate/kargo-analysis-template.yaml) | Integration test Job AnalysisTemplate |
| [manifests/pre-prod-gate/kargo-vcluster-template.yaml](manifests/pre-prod-gate/kargo-vcluster-template.yaml) | VCT with 10-minute sleep and Argo CD import enabled |
| [manifests/pre-prod-gate/kargo-vcluster-instances.yaml](manifests/pre-prod-gate/kargo-vcluster-instances.yaml) | `pre-prod-gate-pre-prod` VCI |
| [manifests/pre-prod-gate/guestbook-apps.yaml](manifests/pre-prod-gate/guestbook-apps.yaml) | Argo CD Applications for pre-prod and prod, both pointing at pre-prod-gate-specific stage overlays with a shared host-cluster `ExternalSecret` |

The pre-prod-gate guestbook overlays under [guestbook/stages/pre-prod-gate-pre-prod](guestbook/stages/pre-prod-gate-pre-prod/kustomization.yaml) and [guestbook/stages/pre-prod-gate-prod](guestbook/stages/pre-prod-gate-prod/kustomization.yaml) both render the same `guestbook-shared-config` Secret from `ClusterSecretStore/pre-prod-gate-shared-demo-store`, then expose it to the app as `DEMO_SHARED_MESSAGE`. The host and pre-prod ingress hosts follow the same repo-scoped pattern as the other guestbook stages: `guestbook-pre-prod-{REPLACE_REPO_NAME}.{REPLACE_BASE_DOMAIN}` and `guestbook-prod-{REPLACE_REPO_NAME}.{REPLACE_BASE_DOMAIN}`.

Because this demo store uses ESO's Kubernetes provider, [shared-demo-cluster-store.yaml](manifests/pre-prod-gate/shared-demo-cluster-store.yaml) includes both the `ClusterSecretStore` and its upstream source Secret `guestbook-shared-demo-source`. The `ExternalSecret` creates the runtime Secret consumed by the app, but the source Secret is still needed as the provider-side object that the Kubernetes-backed store reads from. In the shared-node pre-prod vCluster, the vCluster ESO integration syncs that `ExternalSecret` to the host-side namespace so the host-installed ESO components still do the reconciliation work.

---

## Bootstrap notes

### Kargo admin credentials

The legacy Argo CD-managed `kargo-helm-app.yaml` path references two placeholders that must be added to `scripts/replace-text-local.sh`:

| Placeholder | How to generate |
|---|---|
| `{REPLACE_KARGO_ADMIN_PASSWORD_HASH}` | `htpasswd -bnBC 10 "" <password> \| tr -d ':\n' \| sed 's/$2y/$2a/'` |
| `{REPLACE_KARGO_TOKEN_SIGNING_KEY}` | `openssl rand -base64 32` |

If you prefer not to keep those values in Argo CD Helm values, there is now a Flux-owned host-cluster alternative under [../flux/host-apps/kargo](../flux/host-apps/kargo) that reads auth settings from a Secret via `HelmRelease.valuesFrom`. That Flux path is enabled when `continuousPromotion=true` and `flux=true`. The legacy Argo CD-managed Kargo install now lives under [apps-legacy-argo-kargo/kargo-helm-app.yaml](apps-legacy-argo-kargo/kargo-helm-app.yaml) and is selected when `legacyArgoKargo=true`. On the `vind` self-contained path, bootstrap sets that label automatically whenever `continuous-promotion` is enabled without `flux`.

On the Flux path, the live auth secret is rendered by
[../flux/host-apps/kargo/auth/kargo-auth-values-external-secret.yaml](../flux/host-apps/kargo/auth/kargo-auth-values-external-secret.yaml).
That generated Secret is labeled with `reconcile.fluxcd.io/watch: Enabled`, and
the Kargo `HelmRelease` now treats it as required instead of optional. The
Flux bridge also now applies that `ExternalSecret` via its own
`flux-kargo-auth` `Kustomization`, so Kargo install waits for ESO readiness
instead of racing it.

### ESO / bootstrap sequencing

The continuous-promotion Flux path now assumes ESO is part of the bootstrap
critical path:

- the ESO app-of-apps `ApplicationSet` is synced earlier so the operator and
  `ClusterSecretStore` are available sooner
- the ESO Helm app no longer uses Argo CD `Replace=true`, which was contributing
  to webhook/cert bootstrap churn
- the Kargo auth Secret is sourced from a 1Password-backed `ExternalSecret`
- the cluster-level Kargo GitHub webhook receiver secret reads the `token`
  field from the shared `pr-github-receiver-token` item
- the cluster-level Kargo receiver secret and `ClusterConfig` are now split into
  separate Flux `Kustomization`s, so Kargo does not try to publish webhook
  receivers before ESO has rendered the signing secret

That combination is intended to make generator-hosted demo environments recover
cleanly even when ESO takes a while to produce the initial Secrets.

### Kargo version

Check [github.com/akuity/kargo/releases](https://github.com/akuity/kargo/releases) for the latest chart version and update `targetRevision` in either the Flux `HelmRelease` at [../flux/host-apps/kargo/install/kargo-helmrelease.yaml](../flux/host-apps/kargo/install/kargo-helmrelease.yaml) or the legacy Argo CD path at [apps-legacy-argo-kargo/kargo-helm-app.yaml](apps-legacy-argo-kargo/kargo-helm-app.yaml).

### Forgejo runner registration

This section only applies to the `vind` self-contained path. The bootstrap script uses Forgejo offline registration. It registers a repo-scoped runner from inside the Forgejo pod with `forgejo forgejo-cli actions register`, stores the shared 40-character hex secret in `forgejo-runner-offline-registration`, and the runner init container recreates `/data/.runner` with `forgejo-runner create-runner-file` when needed. The Forgejo-side registration uses plain label names, while the runnable label mappings live in [../../vind-demo-cluster/forgejo-runner/forgejo-runner-config.yaml](../../vind-demo-cluster/forgejo-runner/forgejo-runner-config.yaml).

The `vind` runner uses a repo-scoped DinD sidecar and keeps `runner.capacity` at `1`, which matches Forgejo's recommendation to avoid multiple concurrent jobs sharing the same Docker daemon. Keep the Kubernetes Deployment at `replicas: 1` as well: the offline-registration secret represents a single runner identity, and scaling the Deployment would make multiple pods fight over the same local runner state.

If the Secret is missing, re-run bootstrap or recreate it manually:

```bash
secret="$(openssl rand -hex 20)"
kubectl exec -n forgejo deploy/forgejo -- \
  forgejo forgejo-cli actions register \
    --name "vind-${CLUSTER_NAME}-${REPO_NAME}-runner" \
    --scope "${ORG_NAME}/${REPO_NAME}" \
    --labels "docker,ubuntu-latest,ubuntu-22.04,ubuntu-20.04" \
    --secret "$secret"
kubectl create secret generic forgejo-runner-offline-registration \
  --namespace forgejo \
  --from-literal=secret="$secret" \
  --from-literal=instance="http://forgejo-http.forgejo.svc.cluster.local:3000"
```

### Kargo registry credentials outside `vind`

`vind` bootstrap creates the Forgejo image-registry secrets automatically. In Generator, managed, and self-managed installs, only create a Kargo image-credential secret if the image registry is private. Public GHCR repositories do not need one. Generic Kargo image-credential secrets use the label `kargo.akuity.io/cred-type: image` and the target image repository as `repoURL`, for example:

```bash
for ns in progressive-delivery pre-prod-gate; do
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: registry-image-credentials
  namespace: ${ns}
  labels:
    kargo.akuity.io/cred-type: image
stringData:
  repoURL: ${IMAGE_REPOSITORY_PREFIX}/${REPO_NAME}-demo-app
  username: ${REGISTRY_USERNAME}
  password: ${REGISTRY_TOKEN}
EOF
done
```

### Argo CD cluster names

The `destination.name` values in the ApplicationSet and Argo CD Applications follow the pattern `loft-<project>-vcluster-<vci-name>` (e.g. `loft-default-vcluster-pd-dev`). These are set automatically when the VCIs are imported into Argo CD via the `loft.sh/import-argocd: "true"` label on the VCT.

### Production destination (pre-prod-gate)

`guestbook-pre-prod-gate-prod` in [pre-prod-gate/guestbook-apps.yaml](manifests/pre-prod-gate/guestbook-apps.yaml) defaults to the host cluster. Update `destination` to point at a real external production cluster to complete the end-to-end story.

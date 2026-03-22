# Continuous Promotion with Kargo

Demonstrates GitOps-native continuous promotion across isolated Kubernetes environments using [Kargo](https://kargo.akuity.io) and ArgoCD. Each promotion stage is a real, fully isolated Kubernetes cluster (vCluster), provisioned on demand and visible to Kargo as a first-class ArgoCD destination.

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

## What gets deployed

- **Kargo operator** — installed via Helm into the `kargo` namespace; UI available at `https://kargo.{BASE_DOMAIN}`
- **Forgejo runner (vind self-contained only)** — shared CI runner in the `forgejo` namespace; builds and pushes the demo app image on every commit to `src/` or `helm-chart/`
- **Progressive Delivery demo** — classic dev → staging → prod pipeline
- **Pre-Prod Gate demo** — stage → pre-prod vCluster → prod pipeline (CoreWeave pattern)

---

## CI / Image pipeline

The demo app image (`{REPO_NAME}-demo-app`) is built and pushed automatically by a Forgejo Actions workflow (`.forgejo/workflows/build-push.yaml`) whenever `src/` or `helm-chart/` changes land on `main`.

In the `vind` self-contained path, that workflow runs on the shared Forgejo runner deployed into the `forgejo` namespace from [../../vind-demo-cluster/forgejo-runner/act-runner.yaml](../../vind-demo-cluster/forgejo-runner/act-runner.yaml). Managed and self-managed installs need their own Forgejo runner deployment.

The image is tagged with the `appVersion` from `helm-chart/Chart.yaml` and pushed to the Forgejo container registry. The Kargo Warehouse for both demos watches this registry and triggers promotion automatically when a new semver tag appears.

To trigger a new build manually, bump `appVersion` in `helm-chart/Chart.yaml` and push to `main`.

**Key files:**

| File | Purpose |
|---|---|
| [.forgejo/workflows/build-push.yaml](/.forgejo/workflows/build-push.yaml) | Forgejo Actions workflow — builds `src/Dockerfile` and pushes to Forgejo registry |
| [../../vind-demo-cluster/forgejo-runner/act-runner.yaml](../../vind-demo-cluster/forgejo-runner/act-runner.yaml) | Shared vind runner Deployment + DinD sidecar |
| [../../vcluster-gitops/overlays/local-contained/forgejo-runner-app.yaml](../../vcluster-gitops/overlays/local-contained/forgejo-runner-app.yaml) | Argo CD Application deploying the shared vind runner |

---

## Demo 1 — Progressive Delivery

```text
Warehouse ({REPO_NAME}-demo-app from Forgejo registry)
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
| [manifests/progressive-delivery/kargo-project.yaml](manifests/progressive-delivery/kargo-project.yaml) | Kargo Project (creates `progressive-delivery` namespace) |
| [manifests/progressive-delivery/kargo-warehouse.yaml](manifests/progressive-delivery/kargo-warehouse.yaml) | Watches `{REPO_NAME}-demo-app` image tags in Forgejo registry |
| [manifests/progressive-delivery/kargo-stages.yaml](manifests/progressive-delivery/kargo-stages.yaml) | dev, staging, prod Stages + PromotionPolicies |
| [manifests/progressive-delivery/kargo-analysis-template.yaml](manifests/progressive-delivery/kargo-analysis-template.yaml) | curl health-check AnalysisTemplate |
| [manifests/progressive-delivery/kargo-vcluster-template.yaml](manifests/progressive-delivery/kargo-vcluster-template.yaml) | VCT for stage vClusters (ArgoCD import enabled) |
| [manifests/progressive-delivery/kargo-vcluster-instances.yaml](manifests/progressive-delivery/kargo-vcluster-instances.yaml) | pd-dev, pd-staging, pd-prod VCIs |
| [manifests/progressive-delivery/guestbook-appset.yaml](manifests/progressive-delivery/guestbook-appset.yaml) | ApplicationSet deploying the app into each vCluster via cluster generator |

---

## Demo 2 — Pre-Prod Gate

Inspired by a real-world pattern: uses a long-lived pre-prod vCluster running on the same underlying hardware as production to test changes before they reach real prod clusters. The vCluster scales to zero between promotions, eliminating idle cost.

```text
Warehouse ({REPO_NAME}-demo-app from Forgejo registry)
    │
    ▼ auto-promote
  stage (host cluster namespace)
    │
    ▼ manual promote → integration test Job → pass required
  pre-prod-vcluster (ppg-pre-prod vCluster — scales to zero when idle)
    │  └─ 10 minute soak time required
    ▼ manual approval required
  prod (production cluster)
```

**Verification:** A Kubernetes Job runs inside the cluster against the pre-prod vCluster's ingress URL. The job retries for up to 2 minutes to account for vCluster wake-up time after scale-to-zero. Pass = exit 0, fail = exit 1.

**Key files:**

| File | Purpose |
|---|---|
| [manifests/pre-prod-gate/kargo-project.yaml](manifests/pre-prod-gate/kargo-project.yaml) | Kargo Project (creates `pre-prod-gate` namespace) |
| [manifests/pre-prod-gate/kargo-warehouse.yaml](manifests/pre-prod-gate/kargo-warehouse.yaml) | Watches `{REPO_NAME}-demo-app` image tags in Forgejo registry |
| [manifests/pre-prod-gate/kargo-stages.yaml](manifests/pre-prod-gate/kargo-stages.yaml) | stage, pre-prod-vcluster, prod Stages + soak time |
| [manifests/pre-prod-gate/kargo-analysis-template.yaml](manifests/pre-prod-gate/kargo-analysis-template.yaml) | Integration test Job AnalysisTemplate |
| [manifests/pre-prod-gate/kargo-vcluster-template.yaml](manifests/pre-prod-gate/kargo-vcluster-template.yaml) | VCT with 10-minute sleep, ArgoCD import enabled |
| [manifests/pre-prod-gate/kargo-vcluster-instances.yaml](manifests/pre-prod-gate/kargo-vcluster-instances.yaml) | ppg-pre-prod VCI |
| [manifests/pre-prod-gate/guestbook-apps.yaml](manifests/pre-prod-gate/guestbook-apps.yaml) | ArgoCD Applications for stage, pre-prod, and prod |

---

## Bootstrap notes

### Kargo admin credentials

`kargo-helm-app.yaml` references two placeholders that must be added to `scripts/replace-text-local.sh`:

| Placeholder | How to generate |
|---|---|
| `{REPLACE_KARGO_ADMIN_PASSWORD_HASH}` | `htpasswd -bnBC 10 "" <password> \| tr -d ':\n' \| sed 's/$2y/$2a/'` |
| `{REPLACE_KARGO_TOKEN_SIGNING_KEY}` | `openssl rand -base64 32` |

### Kargo version

Check [github.com/akuity/kargo/releases](https://github.com/akuity/kargo/releases) for the latest chart version and update `targetRevision` in [apps/kargo-helm-app.yaml](apps/kargo-helm-app.yaml).

### Forgejo runner registration

In the `vind` self-contained path, the bootstrap script uses Forgejo offline registration. It registers a repo-scoped runner from inside the Forgejo pod with `forgejo forgejo-cli actions register`, stores the shared 40-character hex secret in `act-runner-offline-registration`, and the runner init container recreates `/data/.runner` with `forgejo-runner create-runner-file` when needed.

If the Secret is missing, re-run bootstrap or recreate it manually:

```bash
secret="$(openssl rand -hex 20)"
kubectl exec -n forgejo deploy/forgejo -- \
  forgejo forgejo-cli actions register \
    --name "vind-${CLUSTER_NAME}-${REPO_NAME}-runner" \
    --scope "${ORG_NAME}/${REPO_NAME}" \
    --labels "ubuntu-latest:docker://node:20-bookworm,ubuntu-22.04:docker://node:20-bookworm,ubuntu-20.04:docker://node:18-bullseye" \
    --secret "$secret"
kubectl create secret generic act-runner-offline-registration \
  --namespace forgejo \
  --from-literal=secret="$secret" \
  --from-literal=instance="http://forgejo-http.forgejo.svc.cluster.local:3000"
```

### ArgoCD cluster names

The `destination.name` values in the ApplicationSet and ArgoCD Applications follow the pattern `loft-<project>-vcluster-<vci-name>` (e.g. `loft-default-vcluster-pd-dev`). These are set automatically when the VCIs are imported into ArgoCD via the `loft.sh/import-argocd: "true"` label on the VCT.

### Production destination (pre-prod-gate)

`guestbook-prod-ppg` in [pre-prod-gate/guestbook-apps.yaml](manifests/pre-prod-gate/guestbook-apps.yaml) defaults to the host cluster. Update `destination` to point at a real external production cluster to complete the end-to-end story.

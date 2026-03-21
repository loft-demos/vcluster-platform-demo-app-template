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
- **Progressive Delivery demo** — classic dev → staging → prod pipeline
- **Pre-Prod Gate demo** — stage → pre-prod vCluster → prod pipeline (CoreWeave pattern)

---

## Demo 1 — Progressive Delivery

```
Warehouse (ghcr.io/akuity/guestbook)
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

**Verification:** After promoting to staging, Kargo runs an `AnalysisRun` that curl-checks the guestbook ingress URL. Only on pass does freight become eligible for prod.

**Key files:**

| File | Purpose |
|---|---|
| [manifests/progressive-delivery/kargo-project.yaml](manifests/progressive-delivery/kargo-project.yaml) | Kargo Project (creates `progressive-delivery` namespace) |
| [manifests/progressive-delivery/kargo-warehouse.yaml](manifests/progressive-delivery/kargo-warehouse.yaml) | Tracks `ghcr.io/akuity/guestbook` image tags |
| [manifests/progressive-delivery/kargo-stages.yaml](manifests/progressive-delivery/kargo-stages.yaml) | dev, staging, prod Stages + PromotionPolicies |
| [manifests/progressive-delivery/kargo-analysis-template.yaml](manifests/progressive-delivery/kargo-analysis-template.yaml) | curl health-check AnalysisTemplate |
| [manifests/progressive-delivery/kargo-vcluster-template.yaml](manifests/progressive-delivery/kargo-vcluster-template.yaml) | VCT for stage vClusters (ArgoCD import enabled) |
| [manifests/progressive-delivery/kargo-vcluster-instances.yaml](manifests/progressive-delivery/kargo-vcluster-instances.yaml) | pd-dev, pd-staging, pd-prod VCIs |
| [manifests/progressive-delivery/guestbook-apps.yaml](manifests/progressive-delivery/guestbook-apps.yaml) | ArgoCD Applications deploying guestbook into each vCluster |

---

## Demo 2 — Pre-Prod Gate

Inspired by a real-world pattern: uses a long-lived pre-prod vCluster running on the same underlying hardware as production to test changes before they reach real prod clusters. The vCluster scales to zero between promotions, eliminating idle cost.

```
Warehouse (ghcr.io/akuity/guestbook)
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
| [manifests/pre-prod-gate/kargo-warehouse.yaml](manifests/pre-prod-gate/kargo-warehouse.yaml) | Tracks `ghcr.io/akuity/guestbook` image tags |
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

### Guestbook ArgoCD Applications

The `guestbook-apps.yaml` files use `ghcr.io/akuity/guestbook` as an OCI Helm chart source — verify this chart is available or swap for an equivalent deployment. The `destination.name` values (`pd-dev`, `pd-staging`, `pd-prod`, `ppg-pre-prod`) must match the ArgoCD cluster entries created when the VCIs are imported.

### Production destination (pre-prod-gate)

`guestbook-prod-ppg` in [pre-prod-gate/guestbook-apps.yaml](manifests/pre-prod-gate/guestbook-apps.yaml) defaults to the host cluster. Update `destination` to point at a real external production cluster to complete the end-to-end story.

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

The demo app image (`{REPO_NAME}-demo-app`) is built and pushed automatically whenever `src/` or `helm-chart/` changes land on `main`.

There are two CI paths in this repo:

- `vind` self-contained uses [../../.forgejo/workflows/build-push.yaml](../../.forgejo/workflows/build-push.yaml) plus the shared Forgejo runner from [../../vind-demo-cluster/forgejo-runner/forgejo-runner.yaml](../../vind-demo-cluster/forgejo-runner/forgejo-runner.yaml)
- GitHub-backed Generator / managed / self-managed flows use the existing GitHub Actions workflows such as [../../.github/workflows/main-build-push.yaml](../../.github/workflows/main-build-push.yaml) on the standard GitHub-hosted runner fleet

In the `vind` self-contained path, the shared Forgejo runner follows Forgejo's Docker-access guidance by exposing an isolated pod-local DinD socket to job containers and exporting `DOCKER_HOST` so workflow steps can reach it.

The demo app image is tagged with the `appVersion` from `helm-chart/Chart.yaml` and pushed to the configured OCI registry. The Kargo Warehouse for both demos watches that image repository and triggers promotion automatically when a new semver tag appears.

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
| [manifests/progressive-delivery/kargo-stages.yaml](manifests/progressive-delivery/kargo-stages.yaml) | dev, staging, prod Stages + PromotionPolicies |
| [manifests/progressive-delivery/kargo-analysis-template.yaml](manifests/progressive-delivery/kargo-analysis-template.yaml) | curl health-check AnalysisTemplate |
| [manifests/progressive-delivery/kargo-vcluster-template.yaml](manifests/progressive-delivery/kargo-vcluster-template.yaml) | VCT for stage vClusters (ArgoCD import enabled) |
| [manifests/progressive-delivery/kargo-vcluster-instances.yaml](manifests/progressive-delivery/kargo-vcluster-instances.yaml) | pd-dev, pd-staging, pd-prod VCIs |
| [manifests/progressive-delivery/guestbook-appset.yaml](manifests/progressive-delivery/guestbook-appset.yaml) | ApplicationSet deploying the app into each vCluster via cluster generator |

---

## Demo 2 — Pre-Prod Gate

Inspired by a real-world pattern: uses a long-lived pre-prod vCluster running on the same underlying hardware as production to test changes before they reach real prod clusters. The vCluster scales to zero between promotions, eliminating idle cost.

```text
Warehouse ({REPO_NAME}-demo-app from configured OCI registry)
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
| [manifests/pre-prod-gate/namespace.yaml](manifests/pre-prod-gate/namespace.yaml) | Pre-creates the `pre-prod-gate` namespace with `kargo.akuity.io/project: "true"` so Kargo can adopt it |
| [manifests/pre-prod-gate/kargo-project.yaml](manifests/pre-prod-gate/kargo-project.yaml) | Kargo Project (adopts the labeled `pre-prod-gate` namespace) |
| [manifests/pre-prod-gate/kargo-warehouse.yaml](manifests/pre-prod-gate/kargo-warehouse.yaml) | Watches `{REPO_NAME}-demo-app` image tags in the configured OCI registry |
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

### ArgoCD cluster names

The `destination.name` values in the ApplicationSet and ArgoCD Applications follow the pattern `loft-<project>-vcluster-<vci-name>` (e.g. `loft-default-vcluster-pd-dev`). These are set automatically when the VCIs are imported into ArgoCD via the `loft.sh/import-argocd: "true"` label on the VCT.

### Production destination (pre-prod-gate)

`guestbook-prod-ppg` in [pre-prod-gate/guestbook-apps.yaml](manifests/pre-prod-gate/guestbook-apps.yaml) defaults to the host cluster. Update `destination` to point at a real external production cluster to complete the end-to-end story.

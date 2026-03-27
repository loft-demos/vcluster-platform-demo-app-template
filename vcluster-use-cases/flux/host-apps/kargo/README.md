# Flux-managed Kargo

This path is for a **host-cluster** Kargo install that is reconciled by Flux,
while Argo CD continues to bootstrap Flux itself.

## Ownership boundary

- Argo CD owns the Flux bootstrap objects under `vcluster-use-cases/flux/manifests`
- Argo CD enables this Flux path through the continuous-promotion Flux bridge
  manifests when `continuousPromotion=true` and `flux=true`
- Flux owns the Kargo chart install and the Kargo CR manifests under this directory
- The Kargo chart still installs the workload into the `kargo` namespace

Do not let Argo CD and Flux both manage the Kargo install at the same time.

## Layout

- `auth/` contains the ESO-managed auth `ExternalSecret` for the Helm values
- `install/` contains the Flux-managed Kargo chart install
- `cluster/secrets/` contains the Flux-managed namespace and webhook signing secret
- `cluster/config/` contains the Flux-managed Kargo `ClusterConfig`
- `flux-kargo-auth.yaml` waits for ESO to render the auth Secret before Kargo install starts
- `flux-kargo-install.yaml` waits for the Kargo HelmRelease to become healthy
- `flux-kargo-cluster-secrets.yaml` waits for ESO to render the GitHub webhook secret before `ClusterConfig` is applied
- `flux-kargo-cluster-config.yaml` applies the shared `ClusterConfig` only after both the chart install and webhook secret are ready
- `flux-kargo-pre-prod-gate.yaml` and `flux-kargo-progressive-delivery.yaml` apply the Kargo CR manifests only after the chart install is ready via Flux `dependsOn`
- `continuous-promotion/manifests-flux-kargo/vcluster-flux-demo-kargo-git-repo.yaml` gives the whole bridge a dedicated Flux source so it no longer races the separate `flux-manifests` app

## Secret-backed auth values

The `HelmRelease` reads an optional Secret named `kargo-auth-values` from the
same namespace as the `HelmRelease` (`p-vcluster-flux-demo`) using
`spec.valuesFrom`.

The Secret must contain a single key named `values.yaml`. That YAML blob can
carry any auth-specific chart values you do not want in Git, such as:

- `api.adminAccount.enabled`
- `api.adminAccount.passwordHash`
- `api.adminAccount.tokenSigningKey`
- `api.oidc`

Example plain Secret: `examples/kargo-auth-values-secret.yaml`

The live `ExternalSecret` now lives at `auth/kargo-auth-values-external-secret.yaml`.
Flux gates the Kargo install on that `ExternalSecret` becoming Ready, which
avoids the earlier “HelmRelease starts before ESO has rendered auth” race.

## GitHub / GHCR webhook receiver

This Flux-managed path also carries a cluster-level Kargo webhook receiver for
GitHub package events that originate from GHCR-associated source repositories.

- `cluster/config/cluster-config.yaml` defines a single `ClusterConfig` receiver
- `cluster/secrets/kargo-github-webhook-secret-external-secret.yaml` renders the
  webhook signing secret into `kargo-system-resources`
- the secret is sourced from the `pr-github-receiver-token` 1Password item via
  `ClusterSecretStore/vcp-demo-store`
- When `api.tls.enabled=false`, the main Kargo API serves plain HTTP behind the
  ingress, so the API ingress must use
  `nginx.ingress.kubernetes.io/backend-protocol: "HTTP"` or nginx will return
  `502 Bad Gateway`
- This repo enables `externalWebhooksServer.ingress.enabled` on a dedicated
  webhook host and disables `externalWebhooksServer.tls.enabled`, so
  ingress-nginx can terminate edge TLS with the platform wildcard certificate
  while proxying plain HTTP to the webhook backend without requiring a
  child-cluster TLS Secret or cert-manager `Certificate`

The Kargo receiver URL is published in `ClusterConfig.status.webhookReceivers`.
When both `continuousPromotion=true` and `crossplane=true` are enabled on the
cluster, this repo now auto-applies a Crossplane `KargoGitHubWebhook` claim,
which observes that status URL and creates the corresponding GitHub repository
webhook so new GHCR package events can trigger immediate `Warehouse` refreshes
instead of waiting for polling alone.

Example:

```yaml
apiVersion: demo.loft.sh/v1alpha1
kind: KargoGitHubWebhook
metadata:
  name: kargo-ghcr
  namespace: p-vcluster-flux-demo
spec:
  repoName: {REPLACE_REPO_NAME}
```

The Crossplane composition lives under
[`../../../crossplane/manifests/`](../../../crossplane/manifests/) and
currently assumes the Flux-managed Kargo `ClusterConfig` publishes a single
receiver at `status.webhookReceivers[0]`.

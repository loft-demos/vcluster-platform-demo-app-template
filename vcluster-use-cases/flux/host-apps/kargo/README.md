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

- `install/` contains the Flux-managed Kargo chart install
- `cluster/` contains the Flux-managed Kargo cluster-level webhook receiver config
- `flux-kargo-install.yaml` waits for the Kargo HelmRelease to become healthy
- `flux-kargo-cluster-config.yaml` applies the shared `ClusterConfig` and webhook signing secret only after the chart install is ready
- `flux-kargo-pre-prod-gate.yaml` and `flux-kargo-progressive-delivery.yaml` apply the Kargo CR manifests only after the chart install is ready via Flux `dependsOn`

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

Examples:

- Plain Secret: `examples/kargo-auth-values-secret.yaml`
- ExternalSecret: `examples/kargo-auth-values-external-secret.yaml`

The live `kargo-auth-values-external-secret.yaml` in this directory is wired for
the External Secrets Operator use case and assumes `ClusterSecretStore/vcp-demo-store`
already exists.

## GitHub / GHCR webhook receiver

This Flux-managed path also carries a cluster-level Kargo webhook receiver for
GitHub package events that originate from GHCR-associated source repositories.

- `cluster/cluster-config.yaml` defines a single `ClusterConfig` receiver
- `cluster/kargo-github-webhook-secret-external-secret.yaml` renders the
  webhook signing secret into `kargo-system-resources`
- the secret is sourced from the `pr-github-receiver-token` 1Password item via
  `ClusterSecretStore/vcp-demo-store`
- Kargo's external webhook server speaks HTTPS internally even when ingress TLS
  is terminated upstream, so the ingress must use
  `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"` and Kargo must be
  told `api.tls.terminatedUpstream=true` so it publishes `https://` receiver
  URLs

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

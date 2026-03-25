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
- `flux-kargo-install.yaml` waits for the Kargo HelmRelease to become healthy
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

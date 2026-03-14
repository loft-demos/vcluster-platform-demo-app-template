# vind Demo Cluster

This folder is the starting point for running this repo against a
self-hosted, self-contained demo environment built on
[`vind`](https://www.vcluster.com/docs/vcluster/deploy/control-plane/docker-container/basics).

The intended model is:

1. start a `vind` cluster
2. install Argo CD and External Secrets Operator directly from the `vind`
   `vcluster.yaml`
3. install vCluster Platform into that same `vind` cluster
4. bootstrap secrets from 1Password through ESO
5. let Argo CD install `vcluster-gitops/` and selected use cases

This replaces the secret projection and bootstrap behavior normally supplied by
the [vCluster Platform Demo Generator](https://github.com/loft-demos/loft-demo-base/blob/main/vcluster-platform-demo-generator/README.md).

## Why This Path Exists

The Demo Generator path works well for centrally managed demo environments, but
it couples this repo to generated secrets and pre-installed components such as
Argo CD, Crossplane, and other bootstrap applications.

For a self-hosted demo running on `vind`, the main goals are:

- no dependency on the Demo Generator
- deterministic bootstrap for coworkers
- reuse of the existing GitOps and use-case content in this repo
- minimal manual secret handling

## Bootstrap Assumptions

This bootstrap path assumes:

- Argo CD is installed by [`vcluster.yaml`](./vcluster.yaml)
- ESO is installed by [`vcluster.yaml`](./vcluster.yaml)
- vCluster Platform is installed manually or by a small bootstrap step after
  `vind` is up
- a coworker performing the setup has access to 1Password and can create the
  initial ESO service-account token secret

The local [`vcluster.yaml`](./vcluster.yaml) is tuned for this repo. It:

- is intended to be applied with vCluster CLI `0.32.1`
- starts `vind` with embedded etcd and Kubernetes `v1.35.1`
- installs Argo CD from the current `argo-cd` Helm chart release
- installs ESO from the current `external-secrets` Helm chart release
- creates the namespaces and Argo CD cluster secret this repo expects
- enables only the `eso` app-of-apps label by default so the initial bootstrap
  stays small
- includes a commented-out Forgejo install block for a future local-contained
  mode

## Files In This Folder

- [`vcluster.yaml`](./vcluster.yaml)
  starts the `vind` management cluster with Argo CD, ESO, and the initial
  in-cluster Argo CD cluster secret
- [`eso-cluster-store.yaml`](./eso-cluster-store.yaml)
  defines a 1Password-backed ESO `ClusterSecretStore` for the `vind` cluster
- [`bootstrap-external-secrets.yaml`](./bootstrap-external-secrets.yaml)
  defines the initial management-cluster `ExternalSecret` resources that
  materialize the first set of repo, image, notification, and Crossplane
  credentials

## Bootstrap Sequence

1. Start `vind` with [`vcluster.yaml`](./vcluster.yaml).
2. Install vCluster Platform into the `vind` cluster.
3. Create the bootstrap secret `one-password-sa-token` in the `eso` namespace.
4. Apply [`eso-cluster-store.yaml`](./eso-cluster-store.yaml).
5. Apply [`bootstrap-external-secrets.yaml`](./bootstrap-external-secrets.yaml).
6. Verify that the initial bootstrap secrets reconcile in:
   - `argocd`
   - `vcluster-platform`
   - `crossplane-system`
7. Apply the Argo CD bootstrap application for this repo.
8. Enable additional use cases only after the base secret contract is working.

The `vcluster.yaml` intentionally does not bootstrap this repo's root Argo CD
`Application`, because `vcluster-gitops/` depends on vCluster Platform CRDs
that are not present until Platform is installed.

## Optional Forgejo Mode

[`vcluster.yaml`](./vcluster.yaml) includes a commented-out Forgejo Helm block.
This is the preferred direction for a self-contained demo mode where:

- Git is hosted inside the `vind` cluster
- OCI images can be pushed to the Forgejo package registry
- Argo CD can use polling or Gitea-compatible generators instead of
  GitHub-specific webhooks

Keep Forgejo disabled by default until the repo has a dedicated
`local-contained` overlay, because the current PR automation, notifications,
and some image flows are still GitHub-specific.

## Same-Org vs Different-Org

There are two supported conceptual modes for a repurposed clone of this repo.

### Same-Org Mode

The cloned repo, the application images, and the GitHub automation credentials
all live in the same GitHub org.

This is the simplest mode because:

- one repo credential can often cover all Git reads
- one GHCR credential can cover image pulls
- one GitHub automation credential can cover webhooks and PR flows

### Different-Org Mode

The cloned repo template lives in one org, while images or GitHub automation
may still belong to another org.

This mode requires treating these as separate concerns:

- `REPO_ORG`: where the cloned repo lives
- `IMAGE_ORG`: where GHCR images are pulled from or pushed to
- `AUTOMATION_GITHUB_ORG`: where GitHub webhook or PR automation credentials
  are scoped

The secret contract for both modes is documented in
[`docs/secret-contract.md`](../docs/secret-contract.md).

## Recommended Initial Scope

For the first working `vind` demo environment, enable only:

- vCluster Platform
- Argo CD
- ESO
- `vcluster-gitops/`
- one or two low-friction use cases

Hold these back until the secret flow is stable:

- Crossplane GitHub automation
- PR preview environments
- database connector
- snapshot publishing

## Next Implementation Steps

This folder is only the first layer. The follow-on work is:

1. define and maintain the repo secret contract
2. replace Demo Generator-projected secrets with ESO-managed secrets
3. add a dedicated Argo CD bootstrap application for the `vind` path
4. add per-use-case overlays or labels so only suitable demos are enabled in a
   self-contained environment

# Crossplane

This folder contains the Crossplane installation, providers, and composition
manifests used by this repo.

In this repo, Crossplane is mainly used to:

- provision ephemeral `VirtualClusterInstance` resources through a custom
  `PullRequestEnvironment` claim
- create GitHub repository webhooks through a custom `ArgoCDWebhook` claim
- provide a visual UI for Crossplane resources with Komoplane

These resources support the pull request environment flows under
[`vcluster-use-cases/argocd-vcluster-pull-request-environments/`](../argocd-vcluster-pull-request-environments/),
especially the internal Crossplane-based examples.

## Folder Layout

```text
vcluster-use-cases/crossplane/
├── apps/
│   ├── crossplane-helm-app.yaml
│   ├── crossplane-manifests.yaml
│   ├── crossplane-providers.yaml
│   └── komoplane-helm-app.yaml
├── manifests/
│   ├── argocdwebhook-composition.yaml
│   ├── function-patch-and-transform.yaml
│   ├── github-provider-config.yaml
│   ├── kubernetes-provider-config.yaml
│   ├── pullrequestenvironments-composition.yaml
│   ├── xargocdwebhooks.yaml
│   └── xpullrequestenvironments.yaml
└── providers/
    ├── github-provider.yaml
    └── kubernetes-provider.yaml
```

## Bootstrap Order

The resources in [`apps/`](./apps/) are designed to be applied by Argo CD in
waves:

1. [`crossplane-helm-app.yaml`](./apps/crossplane-helm-app.yaml)
   installs Crossplane into `crossplane-system`
2. [`crossplane-providers.yaml`](./apps/crossplane-providers.yaml)
   applies the provider package manifests from [`providers/`](./providers/)
3. [`komoplane-helm-app.yaml`](./apps/komoplane-helm-app.yaml)
   installs Komoplane into `crossplane-system`
4. [`crossplane-manifests.yaml`](./apps/crossplane-manifests.yaml)
   applies the XRDs, compositions, function, and provider configs from
   [`manifests/`](./manifests/)

## What Each Folder Does

### `apps/`

This folder contains the top-level Argo CD `Application` resources.

- [`crossplane-helm-app.yaml`](./apps/crossplane-helm-app.yaml)
  installs the upstream Crossplane Helm chart, currently pinned to `1.18.2`
- [`crossplane-providers.yaml`](./apps/crossplane-providers.yaml)
  applies the provider package manifests in [`providers/`](./providers/)
- [`komoplane-helm-app.yaml`](./apps/komoplane-helm-app.yaml)
  installs Komoplane and exposes it through an ingress at
  `komoplane-{REPLACE_VCLUSTER_NAME}.{REPLACE_BASE_DOMAIN}`
- [`crossplane-manifests.yaml`](./apps/crossplane-manifests.yaml)
  applies the Crossplane XRDs, compositions, function, and `ProviderConfig`
  resources from [`manifests/`](./manifests/)

### `providers/`

This folder installs the provider packages Crossplane needs.

- [`github-provider.yaml`](./providers/github-provider.yaml)
  installs `crossplane-contrib/provider-upjet-github:v0.18.4`
- [`kubernetes-provider.yaml`](./providers/kubernetes-provider.yaml)
  installs `crossplane-contrib/provider-kubernetes:v0.18.0`
  and grants the provider `cluster-admin` permissions through a
  `ClusterRoleBinding`

The Kubernetes provider uses a `DeploymentRuntimeConfig` named
`provider-kubernetes`, and the provider pod runs with a dedicated service
account in `crossplane-system`.

### `manifests/`

This folder contains the reusable Crossplane API and composition logic.

#### `xpullrequestenvironments.yaml`

[`xpullrequestenvironments.yaml`](./manifests/xpullrequestenvironments.yaml)
defines the `PullRequestEnvironment` claim and `XPullRequestEnvironment`
composite resource.

The claim schema accepts:

- `spec.repo`
- `spec.project`
- `spec.k8sVersion`
- `spec.prNumber`

#### `pullrequestenvironments-composition.yaml`

[`pullrequestenvironments-composition.yaml`](./manifests/pullrequestenvironments-composition.yaml)
implements the `XPullRequestEnvironment` composition in `Pipeline` mode using
the patch-and-transform function.

It creates two `kubernetes.crossplane.io/Object` resources:

- a vCluster Platform `VirtualClusterInstance`
- an OIDC `Secret` for Argo CD

The composition:

- creates the `VirtualClusterInstance` in namespace `p-<project>`
- targets the `pull-request-vcluster` template with `version: 1.0.x`
- combines `k8sVersion`, `prNumber`, and `repo` into the vCluster instance
  `spec.parameters`
- creates a PR-specific Argo CD OIDC secret with generated `clientID`,
  redirect URI, and hostname values

This is the main Crossplane path used by the internal pull request environment
example.

#### `xargocdwebhooks.yaml`

[`xargocdwebhooks.yaml`](./manifests/xargocdwebhooks.yaml) defines the
`ArgoCDWebhook` claim and `XArgoCDWebhook` composite resource.

The claim schema accepts:

- `spec.repoName`
- `spec.virtualClusterNamespace`

#### `argocdwebhook-composition.yaml`

[`argocdwebhook-composition.yaml`](./manifests/argocdwebhook-composition.yaml)
implements the `XArgoCDWebhook` composition in `Resources` mode.

It creates two GitHub `RepositoryWebhook` resources:

- one for the Argo CD API server
- one for the Argo CD ApplicationSet server

Both webhooks:

- listen to `push` and `pull_request` events
- read their destination URLs from secrets named `argo-webhook-url` and
  `argo-appset-webhook-url`
- use `github-provider-config` for GitHub API access

#### `function-patch-and-transform.yaml`

[`function-patch-and-transform.yaml`](./manifests/function-patch-and-transform.yaml)
installs the Crossplane function package
`crossplane-contrib/function-patch-and-transform:v0.6.0`, which the
`pullrequestenvironments` composition uses in its pipeline.

#### Provider Configs

- [`github-provider-config.yaml`](./manifests/github-provider-config.yaml)
  configures the GitHub provider to read credentials from the
  `github-provider-secret` secret in `crossplane-system`
- [`kubernetes-provider-config.yaml`](./manifests/kubernetes-provider-config.yaml)
  configures the Kubernetes provider to use `InjectedIdentity`

## How Crossplane Is Used In This Repo

Crossplane here is not a general-purpose platform abstraction layer. It is used
for two focused automation paths:

1. `PullRequestEnvironment` claims create ephemeral vCluster instances and
   supporting OIDC secrets
2. `ArgoCDWebhook` claims create GitHub webhooks that point at Argo CD

The internal pull request environment flow under
[`vcluster-use-cases/argocd-vcluster-pull-request-environments/internal/`](../argocd-vcluster-pull-request-environments/internal/)
depends on these Crossplane APIs.

## Required Secrets and Inputs

Before these resources will reconcile successfully, the following inputs must
exist:

- a `github-provider-secret` secret in `crossplane-system` with GitHub
  credentials for the GitHub provider
- the vCluster Platform CRDs and API must already be reachable from the cluster
  because the Kubernetes provider creates `management.loft.sh/v1`
  `VirtualClusterInstance` objects
- `{REPLACE_ORG_NAME}`, `{REPLACE_REPO_NAME}`, `{REPLACE_VCLUSTER_NAME}`, and
  `{REPLACE_BASE_DOMAIN}` placeholders must be replaced where applicable

## Notes

- The Kubernetes provider is granted broad permissions through a
  `cluster-admin` binding in
  [`kubernetes-provider.yaml`](./providers/kubernetes-provider.yaml).
- The `PullRequestEnvironment` composition hardcodes `clusterRef.cluster:
  loft-cluster` and `owner.team: api-framework`, so it is repo-specific rather
  than generic.
- The `pull-request-vcluster` template referenced by the composition must exist
  for the vCluster instance reconciliation to succeed.

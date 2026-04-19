# Crossplane

This folder contains the Crossplane installation, providers, and composition manifests used by this repo.

In this repo, Crossplane is mainly used to:

- provision ephemeral `VirtualClusterInstance` resources through a custom `PullRequestEnvironment` claim
- create GitHub repository webhooks through a custom `ArgoCDWebhook` claim
- create GitHub repository webhooks for Kargo GHCR refreshes through a custom `KargoGitHubWebhook` claim
- provide a visual UI for Crossplane resources with Komoplane

These resources support the pull request environment flows under [`vcluster-use-cases/argocd-vcluster-pull-request-environments/`](../argocd-vcluster-pull-request-environments/), especially the internal Crossplane-based examples.

## Folder Layout

```text
vcluster-use-cases/crossplane/
├── argocd-webhooks/
│   ├── argocd-appset-webhook-readiness-job.yaml
│   ├── argo-appset-github-webhook.yaml
│   ├── argo-appset-webhook-url-secret.yaml
│   ├── argo-github-webhook.yaml
│   └── argo-webhook-url-secret.yaml
├── apps/
│   ├── crossplane-helm-app.yaml
│   ├── crossplane-manifests.yaml
│   ├── crossplane-providers.yaml
│   └── komoplane-helm-app.yaml
├── manifests/
│   ├── argocdwebhook-composition.yaml
│   ├── function-patch-and-transform.yaml
│   ├── github-provider-config.yaml
│   ├── kargogithubwebhook-composition.yaml
│   ├── kubernetes-provider-config.yaml
│   ├── provider-api-readiness-job.yaml
│   ├── pullrequestenvironments-composition.yaml
│   ├── xargocdwebhooks.yaml
│   ├── xkargogithubwebhooks.yaml
│   └── xpullrequestenvironments.yaml
└── providers/
    ├── github-provider.yaml
    └── kubernetes-provider.yaml
```

## Bootstrap Order

The resources in [`apps/`](./apps/) are designed to be applied by Argo CD in waves:

1. [`crossplane-helm-app.yaml`](./apps/crossplane-helm-app.yaml) installs Crossplane into `crossplane-system`
2. [`crossplane-providers.yaml`](./apps/crossplane-providers.yaml) applies the provider package manifests from [`providers/`](./providers/)
3. [`komoplane-helm-app.yaml`](./apps/komoplane-helm-app.yaml) installs Komoplane into `crossplane-system`
4. [`crossplane-manifests.yaml`](./apps/crossplane-manifests.yaml) applies the XRDs, compositions, function, and provider configs from [`manifests/`](./manifests/) after a `PreSync` readiness hook confirms the provider APIs are registered

## What Each Folder Does

### `apps/`

This folder contains the top-level Argo CD `Application` resources.

- [`crossplane-helm-app.yaml`](./apps/crossplane-helm-app.yaml) installs the upstream Crossplane Helm chart, currently pinned to `1.18.2`
- [`crossplane-providers.yaml`](./apps/crossplane-providers.yaml) applies the provider package manifests in [`providers/`](./providers/)
- [`komoplane-helm-app.yaml`](./apps/komoplane-helm-app.yaml) installs Komoplane and exposes it through an ingress at `komoplane-{REPLACE_VCLUSTER_NAME}.{REPLACE_BASE_DOMAIN}`
- [`crossplane-manifests.yaml`](./apps/crossplane-manifests.yaml) applies the Crossplane XRDs, compositions, function, and `ProviderConfig` resources from [`manifests/`](./manifests/) and skips dry-run failures while provider CRDs are still being registered

### `argocd-webhooks/`

This folder contains the declarative GitHub webhook resources for the Argo CD instance that runs in the Generator vCluster Platform vCluster.

They are synced by the main-path app-of-apps `ApplicationSet` [`argocd-webhooks-appset.yaml`](../../vcluster-gitops/argocd/app-of-apps/argocd-webhooks-appset.yaml).

- [`argocd-appset-webhook-readiness-job.yaml`](./argocd-webhooks/argocd-appset-webhook-readiness-job.yaml) is an Argo CD `PreSync` hook that sends a synthetic GitHub `ping` to the internal ApplicationSet webhook service and blocks the GitHub webhook resources until the controller answers with `200`
- [`argo-webhook-url-secret.yaml`](./argocd-webhooks/argo-webhook-url-secret.yaml) publishes the Generator-vCluster Argo CD API webhook URL in the `argocd` namespace
- [`argo-appset-webhook-url-secret.yaml`](./argocd-webhooks/argo-appset-webhook-url-secret.yaml) publishes the Generator-vCluster Argo CD ApplicationSet webhook URL in the `argocd` namespace
- [`argo-github-webhook.yaml`](./argocd-webhooks/argo-github-webhook.yaml) creates the GitHub `push` webhook for the Generator-vCluster Argo CD API server
- [`argo-appset-github-webhook.yaml`](./argocd-webhooks/argo-appset-github-webhook.yaml) creates the GitHub `push` + `pull_request` webhook for the Generator-vCluster ApplicationSet server

### `providers/`

This folder installs the provider packages Crossplane needs.

- [`github-provider.yaml`](./providers/github-provider.yaml) installs `crossplane-contrib/provider-upjet-github:v0.18.4`
- [`kubernetes-provider.yaml`](./providers/kubernetes-provider.yaml) installs `crossplane-contrib/provider-kubernetes:v0.18.0` and grants the provider `cluster-admin` permissions through a `ClusterRoleBinding`

The Kubernetes provider uses a `DeploymentRuntimeConfig` named `provider-kubernetes`, and the provider pod runs with a dedicated service account in `crossplane-system`.

### `manifests/`

This folder contains the reusable Crossplane API and composition logic.

#### `xpullrequestenvironments.yaml`

[`xpullrequestenvironments.yaml`](./manifests/xpullrequestenvironments.yaml) defines the `PullRequestEnvironment` claim and `XPullRequestEnvironment` composite resource.

The claim schema accepts:

- `spec.repo`
- `spec.project`
- `spec.k8sVersion`
- `spec.prNumber`

#### `pullrequestenvironments-composition.yaml`

[`pullrequestenvironments-composition.yaml`](./manifests/pullrequestenvironments-composition.yaml) implements the `XPullRequestEnvironment` composition in `Pipeline` mode using the patch-and-transform function.

It creates two `kubernetes.crossplane.io/Object` resources:

- a vCluster Platform `VirtualClusterInstance`
- an OIDC `Secret` for Argo CD

The composition:

- creates the `VirtualClusterInstance` in namespace `p-<project>`
- targets the `pull-request-vcluster` template with `version: 1.0.x`
- combines `k8sVersion`, `prNumber`, and `repo` into the vCluster instance `spec.parameters`
- creates a PR-specific Argo CD OIDC secret with generated `clientID`, redirect URI, and hostname values

This is the main Crossplane path used by the internal pull request environment example.

#### `xargocdwebhooks.yaml`

[`xargocdwebhooks.yaml`](./manifests/xargocdwebhooks.yaml) defines the `ArgoCDWebhook` claim and `XArgoCDWebhook` composite resource.

The claim schema accepts:

- `spec.repoName`
- `spec.virtualClusterNamespace`

#### `argocdwebhook-composition.yaml`

[`argocdwebhook-composition.yaml`](./manifests/argocdwebhook-composition.yaml) implements the `XArgoCDWebhook` composition in `Resources` mode.

It creates two GitHub `RepositoryWebhook` resources:

- one for the Argo CD API server
- one for the Argo CD ApplicationSet server

Both webhooks:

- listen to `push` and `pull_request` events
- read their destination URLs from secrets named `argo-webhook-url` and `argo-appset-webhook-url`
- use `github-provider-config` for GitHub API access

#### `xkargogithubwebhooks.yaml`

[`xkargogithubwebhooks.yaml`](./manifests/xkargogithubwebhooks.yaml) defines the `KargoGitHubWebhook` claim and `XKargoGitHubWebhook` composite resource.

The claim schema accepts:

- `spec.repoName`
- `spec.clusterConfigName` with a default of `cluster`

#### `kargogithubwebhook-composition.yaml`

[`kargogithubwebhook-composition.yaml`](./manifests/kargogithubwebhook-composition.yaml) implements the `XKargoGitHubWebhook` composition in `Resources` mode.

It:

- observes the Flux-managed Kargo `ClusterConfig`
- copies the published Kargo receiver URL from `status.webhookReceivers[0].url` into the composite status
- creates a URL `Secret` in `crossplane-system`
- creates a GitHub `RepositoryWebhook` that reads that URL secret and the shared Kargo webhook signing secret

The resulting GitHub webhook listens for:

- `push`
- `package`

This matches Kargo's GitHub receiver guidance for GHCR-associated source repositories.

#### `function-patch-and-transform.yaml`

[`function-patch-and-transform.yaml`](./manifests/function-patch-and-transform.yaml) installs the Crossplane function package `crossplane-contrib/function-patch-and-transform:v0.6.0`, which the `pullrequestenvironments` composition uses in its pipeline.

#### `provider-api-readiness-job.yaml`

[`provider-api-readiness-job.yaml`](./manifests/provider-api-readiness-job.yaml) is an Argo CD `PreSync` hook that waits until the GitHub and Kubernetes provider APIs are discoverable before the app applies `ProviderConfig` resources.

#### Provider Configs

- [`github-provider-config.yaml`](./manifests/github-provider-config.yaml) configures the GitHub provider to read credentials from the `github-provider-secret` secret in `crossplane-system`
- [`kubernetes-provider-config.yaml`](./manifests/kubernetes-provider-config.yaml) configures the Kubernetes provider to use `InjectedIdentity`

## How Crossplane Is Used In This Repo

Crossplane here is not a general-purpose platform abstraction layer. It is used for four focused automation paths:

1. `PullRequestEnvironment` claims create ephemeral vCluster instances and supporting OIDC secrets
2. declarative `RepositoryWebhook` resources create the Generator-vCluster Argo CD GitHub webhooks
3. `ArgoCDWebhook` claims create GitHub webhooks that point at Argo CD for the Argo CD vCluster template path
4. `KargoGitHubWebhook` claims create GitHub webhooks that point at the Kargo cluster-level GitHub receiver URL published in `ClusterConfig` status

When `continuousPromotion=true`, `flux=true`, and `crossplane=true` are all enabled, the repo now auto-applies the Kargo webhook claim through the continuous-promotion app-of-apps path.

The internal pull request environment flow under [`vcluster-use-cases/argocd-vcluster-pull-request-environments/internal/`](../argocd-vcluster-pull-request-environments/internal/) depends on these Crossplane APIs.

## Required Secrets and Inputs

Before these resources will reconcile successfully, the following inputs must exist:

- a `github-provider-secret` secret in `crossplane-system` with GitHub credentials for the GitHub provider
- a Flux-managed Kargo `ClusterConfig` named `cluster` if you want to use the `KargoGitHubWebhook` claim as-is
- the vCluster Platform CRDs and API must already be reachable from the cluster because the Kubernetes provider creates `management.loft.sh/v1` `VirtualClusterInstance` objects
- `{REPLACE_ORG_NAME}`, `{REPLACE_REPO_NAME}`, `{REPLACE_VCLUSTER_NAME}`, and `{REPLACE_BASE_DOMAIN}` placeholders must be replaced where applicable

## Notes

- The Kubernetes provider is granted broad permissions through a `cluster-admin` binding in [`kubernetes-provider.yaml`](./providers/kubernetes-provider.yaml).
- The `PullRequestEnvironment` composition hardcodes `clusterRef.cluster: loft-cluster` and `owner.team: api-framework`, so it is repo-specific rather than generic.
- The `pull-request-vcluster` template referenced by the composition must exist for the vCluster instance reconciliation to succeed.
- The Generator-vCluster Argo CD webhook path now waits for the internal `argocd-applicationset-controller` webhook service to answer a synthetic GitHub `ping` before Crossplane creates the external GitHub webhook objects. If that hook job fails, inspect the `argocd-github-webhooks` Argo CD application and the `argocd-applicationset-controller` deployment before recreating the webhooks.
- If the ApplicationSet controller still advertises a Service endpoint before the webhook listener is actually serving, enable controller readiness and liveness probes in the upstream Generator Argo CD Helm values in `loft-demo-base`.
- The `KargoGitHubWebhook` composition currently assumes this repo's cluster-level Kargo configuration publishes a single receiver at `status.webhookReceivers[0]`. If you add more cluster receivers later, update the composition to select the desired receiver explicitly.
- If a pipeline-mode composition reports `tls: failed to verify certificate` against `function-patch-and-transform`, Crossplane cannot execute that function until the package runtime is restarted or reinstalled. The Kargo webhook composition avoids that dependency by using `Resources` mode.

# Generator Argo CD Webhook Cutover

This repo now carries a dedicated declarative GitHub webhook path for the Argo CD
CD instance installed in the Generator vCluster Platform vCluster.

That Generator-specific path is separate from the existing
`argo-cd-cluster-application-set` app, which still needs to stay unchanged
because it is part of the Argo CD vCluster template flow in
[`vcluster-gitops/virtual-cluster-templates/base/argocd.yaml`](../vcluster-gitops/virtual-cluster-templates/base/argocd.yaml).

The new Generator-vCluster path follows the same broad shape as the Flux
webhook flow:

- publish the external webhook URLs as `Secret`s in Git
- create GitHub `RepositoryWebhook` resources declaratively through Crossplane
- let Argo CD sync them from this repo instead of creating them from the
  upstream Generator repo

## Files In This Repo

- `vcluster-gitops/argocd/app-of-apps/argocd-webhooks-appset.yaml`
- `vcluster-use-cases/crossplane/argocd-webhooks/argocd-appset-webhook-readiness-job.yaml`
- `vcluster-use-cases/crossplane/argocd-webhooks/argo-webhook-url-secret.yaml`
- `vcluster-use-cases/crossplane/argocd-webhooks/argo-appset-webhook-url-secret.yaml`
- `vcluster-use-cases/crossplane/argocd-webhooks/argo-github-webhook.yaml`
- `vcluster-use-cases/crossplane/argocd-webhooks/argo-appset-github-webhook.yaml`

This is in addition to the pre-existing child-vCluster Argo CD path that still
uses:

- `vcluster-gitops/virtual-cluster-templates/base/argocd.yaml`
- `vcluster-gitops/apps/argo-cd-cluster-application-set.yaml`
- `vcluster-use-cases/crossplane/manifests/xargocdwebhooks.yaml`
- `vcluster-use-cases/crossplane/manifests/argocdwebhook-composition.yaml`

The resulting webhook behavior is:

- a `PreSync` hook blocks GitHub webhook creation until the internal
  `argocd-applicationset-controller` webhook endpoint answers a synthetic
  GitHub `ping` with `200`
- the Argo CD API webhook listens for `push`
- the Argo CD ApplicationSet webhook listens for `push` and `pull_request`

## Required Changes In `loft-demo-base`

Keep:

- the `github-repo-argo-cd-webhooks` bootstrap app that seeds the first
  `Application/vcluster-gitops`
- the `DemoRepository` repo creation flow itself

Remove:

- Argo CD `RepositoryWebhook` resources from
  `vcluster-platform-demo-generator/crossplane/vcluster-demo-repository-x/demo-repository-composition.yaml`
- `argo-webhook-url` and `argo-appset-webhook-url` `Secret`s from
  `vcluster-platform-demo-generator/vcluster-platform-gitops/virtual-cluster-templates/vcluster-platform-demo-template.yaml`

The upstream Generator repo should no longer create the Argo CD webhook resources
or the URL secrets once this repo owns them.

## External Prerequisites

These still need to exist for the declarative webhook resources in this repo to
reconcile successfully:

- the cluster-local Argo CD secret must still select the main-path
  Crossplane-backed GitHub flow, for example `crossplane=true`, so
  `argocd-webhooks-appset.yaml` is rendered
- `github-provider-config` in `crossplane-system`
- the secret referenced by `github-provider-config`
- the generated repo placeholders must resolve the correct repo name,
  Generator-vCluster name, and base domain
- if the ApplicationSet controller still exposes a routable Service before its
  webhook listener is serving, add readiness and liveness probes to the
  upstream Generator Argo CD Helm values in `loft-demo-base`
- `argo-cd-cluster-application-set` must remain unchanged so the Argo CD
  vCluster template path continues to work separately from this new Generator
  webhook path

No new GitHub-side manual configuration is required beyond the existing
provider credentials.

The local-contained overlay intentionally does not include
`argocd-webhooks-appset.yaml`, so Forgejo/Gitea environments continue to use
their existing webhook-specific overlay logic instead of these GitHub webhook
resources.

## Cutover Order

Use a single cutover window so both repos do not create the same GitHub
webhooks at the same time:

1. Deploy this repo version in the generated repo template flow.
2. Remove the Argo CD webhook resources and URL secrets from `loft-demo-base`.
3. Recreate or update the affected Generator environments so only this repo
   owns those webhooks.
4. Verify each generated GitHub repo now has exactly one Argo CD API webhook
   and one Argo CD ApplicationSet webhook after the old upstream-owned
   resources are gone.

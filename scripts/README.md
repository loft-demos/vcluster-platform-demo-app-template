# Scripts

This folder has seven scripts that matter for the self-contained `vind` path.

## `replace-text-local.sh`

Replaces the repo placeholders locally.

Default example:

```bash
bash scripts/replace-text-local.sh \
  --repo-name vcp-gitops \
  --org-name vcluster-demos \
  --include-md
```

Defaults:

- repo: `vcp-gitops`
- org: `vcluster-demos`
- base domain: `vcp.local`
- git base URL: `http://forgejo-http.forgejo.svc.cluster.local:3000`
- git public URL: `https://forgejo.vcp.local`
- image repository prefix: `forgejo.vcp.local/vcluster-demos/vcp-gitops`

## `bootstrap-forgejo-repo.sh`

Creates the Forgejo repo and pushes the local repo into it.

Example:

```bash
bash scripts/bootstrap-forgejo-repo.sh \
  --forgejo-url https://forgejo.vcp.local \
  --username demo-admin \
  --password "$FORGEJO_ADMIN_PASSWORD" \
  --owner vcluster-demos \
  --owner-type org \
  --repo vcp-gitops \
  --include-working-tree
```

`--include-working-tree` is what makes the local replacement output show up in
Forgejo without committing local changes first.

## `build-push-forgejo-image.sh`

Builds `src/Dockerfile` and pushes the demo image to the Forgejo container
registry.

Example:

```bash
bash scripts/build-push-forgejo-image.sh \
  --registry forgejo.vcp.local \
  --image-repository-prefix forgejo.vcp.local/vcluster-demos/vcp-gitops \
  --repo-name vcp-gitops \
  --username demo-admin \
  --password "$FORGEJO_ADMIN_PASSWORD"
```

It pushes:

- the local git short SHA tag
- the Helm chart `appVersion` tag
- as image `forgejo.vcp.local/vcluster-demos/vcp-gitops/vcp-gitops-demo-app`

## `configure-forgejo-webhook.sh`

Creates or updates a Forgejo repository webhook for Argo CD or another in-cluster consumer.

Example:

```bash
bash scripts/configure-forgejo-webhook.sh \
  --forgejo-url https://forgejo.vcp.local \
  --username demo-admin \
  --token "$FORGEJO_TOKEN" \
  --owner vcluster-demos \
  --repo vcp-gitops \
  --webhook-url http://argocd-applicationset-controller.argocd.svc.cluster.local:7000/api/webhook \
  --type gitea \
  --events pull_request
```

## `configure-forgejo-labels.sh`

Creates or updates a single label in a Forgejo repository. Used during bootstrap
to create the PR workflow labels that the `flux` and `argocd-vcluster-pull-request-environments`
use cases rely on. This replaces the Crossplane `IssueLabels` resource, which requires the
GitHub provider and is not available in the vind environment.

Example:

```bash
bash scripts/configure-forgejo-labels.sh \
  --forgejo-url https://forgejo.vcp.local \
  --username demo-admin \
  --token "$FORGEJO_TOKEN" \
  --owner vcluster-demos \
  --repo vcp-gitops \
  --label-name 'deploy/flux-vcluster-preview' \
  --label-color 'c5def5' \
  --label-description 'PR preview vCluster instances with a matrix of Kubernetes versions via Flux'
```

## `configure-flux-webhook.sh`

Registers a Forgejo webhook for the Flux `pr-github-receiver`. Looks up the
Receiver's dynamic webhook path from the cluster (`.status.webhookPath`), then
calls `configure-forgejo-webhook.sh` with the full URL. Safe to re-run — if the
webhook already exists it will be updated rather than duplicated.

Use this script when flux is enabled after the initial bootstrap, or to
re-register the webhook after the Receiver is recreated.

Example:

```bash
bash scripts/configure-flux-webhook.sh \
  --forgejo-url https://forgejo.vcp.local \
  --username demo-admin \
  --token "$FORGEJO_TOKEN" \
  --owner vcluster-demos \
  --repo vcp-gitops \
  --vcluster-name vcp-gitops \
  --base-domain vcp.local
```

## `update-templates.sh`

Updates Kubernetes and vCluster chart versions across the template manifests.

Run it with:

```bash
bash scripts/update-templates.sh
```

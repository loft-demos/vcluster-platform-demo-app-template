# Scripts

This folder has nine scripts that matter for the self-contained `vind` path.

## `replace-text-local.sh`

Replaces the repo placeholders locally.

Default example:

```bash
bash scripts/replace-text-local.sh \
  --repo-name vcp-gitops \
  --org-name vcluster-demos \
  --forgejo-host forgejo.vcp.local \
  --include-md
```

Branch-test example:

```bash
bash scripts/replace-text-local.sh \
  --repo-name vcp-gitops \
  --org-name vcluster-demos \
  --git-target-revision use-case/branch-test \
  --forgejo-host forgejo.vcp.local \
  --include-md
```

Use `--git-target-revision <branch>` when you want self-repo Argo CD and Flux references to render against a non-default test branch.

Defaults:

- repo: `vcp-gitops`
- org: `vcluster-demos`
- base domain: `vcp.local`
- git target revision: `main`
- Kargo host: `kargo.vcp.local`
- Kargo webhook host: `kargo-webhooks.vcp.local`
- git base URL: `http://forgejo-http.forgejo.svc.cluster.local:3000`
- git public URL: `http://forgejo.vcp.local`
- image repository prefix: `forgejo.vcp.local/vcluster-demos/vcp-gitops`

## `bootstrap-forgejo-repo.sh`

Creates the Forgejo repo and pushes the local repo into it.

Example:

```bash
bash scripts/bootstrap-forgejo-repo.sh \
  --forgejo-url http://forgejo.vcp.local \
  --username demo-admin \
  --password "$FORGEJO_ADMIN_PASSWORD" \
  --owner vcluster-demos \
  --owner-type org \
  --repo vcp-gitops \
  --include-working-tree
```

`--include-working-tree` is what makes the local replacement output show up in Forgejo without committing local changes first.

Use this from the rendered `vind` runtime checkout, not from the template-style source checkout with unresolved `{REPLACE_*}` placeholders. The script now refuses to push a working-tree snapshot if critical runtime files such as the Forgejo build workflow still contain unresolved placeholders.

## `build-push-forgejo-image.sh`

Builds a Dockerfile and pushes it to the Forgejo container registry. The default path is the demo app image from `src/Dockerfile`.

Example:

```bash
bash scripts/build-push-forgejo-image.sh \
  --registry forgejo.vcp.local \
  --image-repository-prefix forgejo.vcp.local/vcluster-demos/vcp-gitops \
  --repo-name vcp-gitops \
  --username demo-admin \
  --password "$FORGEJO_ADMIN_PASSWORD"
```

By default it pushes:

- the local git short SHA tag
- the Helm chart `appVersion` tag
- as image `forgejo.vcp.local/vcluster-demos/vcp-gitops/vcp-gitops-demo-app`

It also supports overrides such as:

- `--image-name` to change the image name under the repo-scoped prefix
- `--context` and `--dockerfile` to build something other than `src/`
- `--extra-tag latest` for stable helper tags alongside the immutable git SHA

## `configure-forgejo-webhook.sh`

Creates or updates a Forgejo repository webhook for Argo CD or another in-cluster consumer.

Example:

```bash
bash scripts/configure-forgejo-webhook.sh \
  --forgejo-url http://forgejo.vcp.local \
  --username demo-admin \
  --token "$FORGEJO_TOKEN" \
  --owner vcluster-demos \
  --repo vcp-gitops \
  --webhook-url http://argocd-applicationset-controller.argocd.svc.cluster.local:7000/api/webhook \
  --type gitea \
  --events pull_request
```

## `configure-forgejo-labels.sh`

Creates or updates a single label in a Forgejo repository. Used during bootstrap to create the PR workflow labels that the `flux` and `argocd-vcluster-pull-request-environments` use cases rely on. This replaces the Crossplane `IssueLabels` resource, which requires the GitHub provider and is not available in the vind environment.

Example:

```bash
bash scripts/configure-forgejo-labels.sh \
  --forgejo-url http://forgejo.vcp.local \
  --username demo-admin \
  --token "$FORGEJO_TOKEN" \
  --owner vcluster-demos \
  --repo vcp-gitops \
  --label-name 'deploy/flux-vcluster-preview' \
  --label-color 'c5def5' \
  --label-description 'PR preview vCluster instances with a matrix of Kubernetes versions via Flux'
```

## `configure-forgejo-actions-secret.sh`

Creates or updates a Forgejo repository Actions secret. The `vind` bootstrap now uses this to seed `FORGEJO_PASSWORD` for the `build-push` workflow.

Example:

```bash
bash scripts/configure-forgejo-actions-secret.sh \
  --forgejo-url http://forgejo.vcp.local \
  --username demo-admin \
  --password "$FORGEJO_ADMIN_PASSWORD" \
  --owner vcluster-demos \
  --repo vcp-gitops \
  --secret-name FORGEJO_PASSWORD \
  --secret-value "$FORGEJO_ADMIN_PASSWORD"
```

## `configure-flux-webhook.sh`

Registers a Forgejo webhook for the Flux `pr-github-receiver`. Looks up the Receiver's dynamic webhook path from the cluster (`.status.webhookPath`), then calls `configure-forgejo-webhook.sh` with the full URL. Safe to re-run — if the webhook already exists it will be updated rather than duplicated.

Use this script when flux is enabled after the initial bootstrap, or to re-register the webhook after the Receiver is recreated.

Example:

```bash
bash scripts/configure-flux-webhook.sh \
  --forgejo-url http://forgejo.vcp.local \
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

## `test-pre-prod-wakeup.sh`

Reproduces the sleeping-pre-prod Argo CD wake-up scenario for the continuous-promotion demo.

Examples:

```bash
bash scripts/test-pre-prod-wakeup.sh status
```

```bash
bash scripts/test-pre-prod-wakeup.sh scenario
```

The `scenario` mode force-sleeps `pre-prod-gate-pre-prod`, tails the Argo CD `vcluster-gitops-watcher` logs, then triggers a manual sync on `guestbook-ppg-pre-prod` so you can verify that the shared watcher wakes a sleeping destination and toggles the imported cluster Secret's `skip-reconcile` annotation as the vCluster moves through sleeping, waking, and ready states.

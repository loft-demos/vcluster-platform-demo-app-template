# Scripts

This folder has four scripts that matter for the self-contained `vind` path.

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
- image repository prefix: `forgejo.vcp.local/vcluster-demos`

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
  --image-repository-prefix forgejo.vcp.local/vcluster-demos \
  --repo-name vcp-gitops \
  --username demo-admin \
  --password "$FORGEJO_ADMIN_PASSWORD"
```

It pushes:

- the local git short SHA tag
- the Helm chart `appVersion` tag

## `update-templates.sh`

Updates Kubernetes and vCluster chart versions across the template manifests.

Run it with:

```bash
bash scripts/update-templates.sh
```

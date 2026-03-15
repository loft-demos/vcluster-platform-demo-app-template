# Scripts

This folder has three scripts that matter for the self-contained `vind` path.

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

## `update-templates.sh`

Updates Kubernetes and vCluster chart versions across the template manifests.

Run it with:

```bash
bash scripts/update-templates.sh
```

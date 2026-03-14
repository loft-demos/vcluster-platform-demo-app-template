# vCluster Platform Demo Repository

![Supports vCluster Inception](https://img.shields.io/badge/vCluster-Inception%20Ready-blueviolet?style=flat-square&logo=kubernetes)

This repository is the GitOps and use-case template for vCluster Platform demo
environments. It can be used in three ways:

- with the managed [vCluster Platform Demo Generator](./vcluster-platform-demo-generator.md)
- on a self-managed host cluster via [self-managed-demo-cluster/README.md](./self-managed-demo-cluster/README.md)
- on a self-contained `vind` management cluster via [vind-demo-cluster/README.md](./vind-demo-cluster/README.md)

The repo was originally optimized for the Demo Generator path, but it now also
includes a real `vind` bootstrap path, a first-pass local-contained Git flow
using Forgejo, and an OrbStack-specific local domain pattern for SE laptops.

## Deployment Modes

| Mode | Best Fit | Entry Point |
|------|----------|-------------|
| Managed Demo Generator | centrally managed demo environments with automated repo creation, webhook setup, and pre-wired secrets | [vcluster-platform-demo-generator.md](./vcluster-platform-demo-generator.md) |
| Self-managed | bring-your-own cluster with manually bootstrapped vCluster Platform and Argo CD | [self-managed-demo-cluster/README.md](./self-managed-demo-cluster/README.md) |
| `vind` | self-contained demos on a laptop or local machine | [vind-demo-cluster/README.md](./vind-demo-cluster/README.md) |

## Current `vind` Direction

The intended default pattern for `vind` is:

- embedded or local-contained Forgejo for Git hosting
- Argo CD pull request generators switched to `gitea`
- OrbStack local domains such as `vcp.local`, `argocd.vcp.local`, and `forgejo.vcp.local`
- no required public domain

That path is started, but not fully complete yet. The current status is:

- repo-specific `vind` bootstrap: [vind-demo-cluster/vcluster.yaml](./vind-demo-cluster/vcluster.yaml)
- step-by-step `vind` installer with license-token and Platform-version overrides: [vind-demo-cluster/install-vind.sh](./vind-demo-cluster/install-vind.sh)
- 1Password + ESO bootstrap model: [docs/secret-contract.md](./docs/secret-contract.md)
- first-pass local-contained overlay: [vcluster-gitops/overlays/local-contained/README.md](./vcluster-gitops/overlays/local-contained/README.md)
- Forgejo repo bootstrap script: [scripts/bootstrap-forgejo-repo.sh](./scripts/bootstrap-forgejo-repo.sh)
- local placeholder replacement script: [scripts/replace-text-local.sh](./scripts/replace-text-local.sh)
- OrbStack local domain adapter: [vind-demo-cluster/orbstack-domains](./vind-demo-cluster/orbstack-domains)

When you need public GitHub webhooks or public demo URLs instead, the fallback
path is Cloudflare Tunnel:

- [vind-demo-cluster/cloudflare-tunnel.yaml](./vind-demo-cluster/cloudflare-tunnel.yaml)

## Repository Layout

- [vcluster-gitops/](./vcluster-gitops)
  vCluster Platform GitOps resources, Argo CD bootstrap content, projects,
  project secrets, teams, users, virtual cluster templates, and example
  virtual cluster instances
- [vcluster-use-cases/](./vcluster-use-cases)
  selectable demo use cases, each documented in its own folder when applicable
- [vind-demo-cluster/](./vind-demo-cluster)
  `vind` bootstrap manifests, docs, Cloudflare Tunnel template, and OrbStack
  local domain setup
- [self-managed-demo-cluster/](./self-managed-demo-cluster)
  self-managed bootstrap guidance for a traditional host cluster
- [scripts/](./scripts)
  repo maintenance and local bootstrap automation
- [helm-chart/](./helm-chart)
  demo application Helm chart used by several GitOps and pull request examples
- [src/](./src)
  demo application source

## Key Flows

### vCluster Platform GitOps

The main management cluster GitOps content is in [vcluster-gitops/](./vcluster-gitops).
This includes:

- Argo CD bootstrap applications and ApplicationSets
- vCluster Platform projects, roles, teams, users, and project secrets
- base and overlay `VirtualClusterTemplate` manifests
- demo-use-case installation triggers driven by Argo CD cluster secret labels

### Use Cases

The repo includes examples for:

- Argo CD in virtual clusters
- Argo CD add-ons for virtual clusters
- pull request preview environments
- External Secrets Operator
- Crossplane
- Flux
- database connector
- custom resource sync
- namespace sync
- resolve DNS
- virtual scheduler
- vNode with vCluster
- auto snapshots
- connected host cluster
- Rancher integration
- central admission control

The catalog lives under [vcluster-use-cases/](./vcluster-use-cases).

### Local-Contained PR Flow

The new first-pass `local-contained` path converts the PR-oriented Argo CD flows
from `github` to `gitea` in an overlay rather than rewriting the base manifests:

- [vcluster-gitops/overlays/local-contained/README.md](./vcluster-gitops/overlays/local-contained/README.md)

This path is intentionally scoped. It does not yet replace all GitHub-specific
or GHCR-specific automation across the repo.

## Automation

### Template and Version Updates

[scripts/update-templates.sh](./scripts/update-templates.sh) updates Kubernetes
version options and vCluster chart versions across template manifests. It is
also used by the repo automation workflow.

### Forgejo Bootstrap

[scripts/bootstrap-forgejo-repo.sh](./scripts/bootstrap-forgejo-repo.sh)
creates a repo in Forgejo and pushes the current local branches and tags into
it. This is the best current automation for the local-contained `vind` path.

Example:

```bash
bash scripts/bootstrap-forgejo-repo.sh \
  --forgejo-url https://forgejo.vcp.local \
  --username demo-admin \
  --token "$FORGEJO_TOKEN" \
  --owner loft-demos \
  --repo vcluster-platform-demo-app-template
```

## Argo CD and vCluster Platform Integration

This repo relies heavily on the vCluster Platform Argo CD integration:

- virtual clusters can be imported into Argo CD automatically
- `instanceTemplate.metadata.labels` from `VirtualClusterTemplate` manifests
  can become selectors on generated Argo CD cluster secrets
- those labels are then used by Argo CD `ApplicationSet` cluster generators to
  install optional demo content

The main examples for that pattern are in:

- [vcluster-gitops/argocd/README.md](./vcluster-gitops/argocd/README.md)
- [vcluster-use-cases/argocd-in-vcluster/README.md](./vcluster-use-cases/argocd-in-vcluster/README.md)
- [vcluster-use-cases/argocd-vcluster-add-ons/README.md](./vcluster-use-cases/argocd-vcluster-add-ons/README.md)

## Recommended Starting Points

- If you want the fully managed path: start with [vcluster-platform-demo-generator.md](./vcluster-platform-demo-generator.md)
- If you want a traditional cluster you manage yourself: start with [self-managed-demo-cluster/README.md](./self-managed-demo-cluster/README.md)
- If you want the laptop-friendly self-contained path: start with [vind-demo-cluster/README.md](./vind-demo-cluster/README.md)

For `vind`, use this sequence:

1. start `vind`
   - recommended: `LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/install-vind.sh`
   - override the default Platform version when needed: `bash vind-demo-cluster/install-vind.sh --license-token "$TOKEN" --vcp-version 4.7.1`
   - `vind-demo-cluster/vcluster.yaml` is now a rendered template, so do not pass it directly to `vcluster create` unless you render its placeholders yourself
2. clone this repo directly and initialize it locally with [scripts/replace-text-local.sh](./scripts/replace-text-local.sh)
   - a GitHub template copy is not required for the self-contained path
3. configure ESO and 1Password using [docs/secret-contract.md](./docs/secret-contract.md)
4. choose either:
   - OrbStack local-contained mode with [vind-demo-cluster/orbstack-domains](./vind-demo-cluster/orbstack-domains)
   - Cloudflare Tunnel fallback with [vind-demo-cluster/cloudflare-tunnel.yaml](./vind-demo-cluster/cloudflare-tunnel.yaml)
5. bootstrap the repo into Forgejo if you are following the local-contained path
6. apply the GitOps bootstrap for this repo

## Known Gaps

The repo now has a credible `vind` path, but the following are still incomplete
for a fully local-contained default:

- Forgejo is still commented out in [vind-demo-cluster/vcluster.yaml](./vind-demo-cluster/vcluster.yaml)
- Crossplane GitHub provider flows are not converted to Forgejo
- some GHCR-specific image flows still assume GitHub Container Registry
- the root Argo CD bootstrap application for `vind` is not added yet
- some docs and examples still describe the older Generator-first assumptions

## Notes

- Use `vCluster instances` or `virtual clusters` in public-facing wording.
- For modern `0.32.0+` templates in this repo, sleep and deletion config has
  already been updated to the newer shape and Go duration format.
- The `vind` bootstrap currently targets vCluster CLI `0.32.1`.

## Contributing

This repo is maintained for demo and solution-engineering workflows. Copy it,
adapt it, and tune the use cases to the environment you actually need.

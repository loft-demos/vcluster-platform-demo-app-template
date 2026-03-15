# vCluster Platform Demo Repository

This repo is the GitOps and use-case template for vCluster Platform demos.

Use one of these entrypoints:

- managed: [vcluster-platform-demo-generator.md](./vcluster-platform-demo-generator.md)
- self-managed host cluster: [self-managed-demo-cluster/README.md](./self-managed-demo-cluster/README.md)
- self-contained `vind`: [vind-demo-cluster/README.md](./vind-demo-cluster/README.md)

If you want the shortest path, use `vind`:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh
```

Default `vind` values:

- Forgejo org: `vcluster-demos`
- Forgejo repo: `vcp-gitops`
- local URLs:
  - <https://vcp.local>
  - <https://argocd.vcp.local>
  - <https://forgejo.vcp.local>
- cluster shape: `1` control plane node, `2` worker nodes

Main repo areas:

- [vcluster-gitops/](./vcluster-gitops): Platform GitOps content, Argo CD bootstrap, projects, teams, secrets, templates
- [vcluster-use-cases/](./vcluster-use-cases): demo use cases
- [vind-demo-cluster/](./vind-demo-cluster): self-contained `vind` bootstrap
- [scripts/](./scripts): local helper scripts
- [docs/secret-contract.md](./docs/secret-contract.md): secret contract for ESO / 1Password

For the self-contained path, the Argo CD root app is:

- [root-application.yaml](./vcluster-gitops/overlays/local-contained/root-application.yaml)

The self-contained Git overlay is:

- [vcluster-gitops/overlays/local-contained/README.md](./vcluster-gitops/overlays/local-contained/README.md)

Notes:

- use `vCluster instances` or `virtual clusters` in public docs
- `0.32.0+` template sleep and deletion config in this repo has already been updated

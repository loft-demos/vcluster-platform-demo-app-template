# vind Demo Cluster

This folder is the self-contained path for this repo.

It uses:

- `vind` for the management cluster
- vCluster Platform, Argo CD, ESO, and Forgejo installed from [vcluster.yaml](./vcluster.yaml)
- OrbStack local domains for laptop access
- the local-contained GitOps overlay for the Argo CD bootstrap

## Quickstart

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh
```

Default behavior:

- Forgejo org: `vcluster-demos`
- Forgejo repo: `vcp-gitops`
- base domain: `vcp.local`
- local URLs:
  - <https://vcp.local>
  - <https://argocd.vcp.local>
  - <https://forgejo.vcp.local>
- cluster shape: `1` control plane node, `2` worker nodes
- control plane taint: `node-role.kubernetes.io/control-plane=:NoSchedule`

What the bootstrap does:

- creates or upgrades the `vind` cluster
- installs vCluster Platform, Argo CD, ESO, and Forgejo
- runs local placeholder replacement
- pushes the repo into Forgejo
- creates the Argo CD Forgejo secrets
- applies the root Argo CD `Application`
- starts the OrbStack domain adapter

The root Argo CD app is:

- [root-application.yaml](../vcluster-gitops/overlays/local-contained/root-application.yaml)

## Most Common Commands

Create or rerun everything:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh
```

Rerun bootstrap logic against an existing cluster:

```bash
bash vind-demo-cluster/bootstrap-self-contained.sh \
  --skip-vind \
  --skip-orbstack-env
```

Use a different repo or org:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --repo-name team-a-gitops \
  --org-name team-a
```

Use more worker nodes:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --worker-nodes 3
```

Delete the environment cleanly:

```bash
bash vind-demo-cluster/delete-vind.sh
```

## Local Access

Default local hostnames:

- <https://vcp.local>
- <https://argocd.vcp.local>
- <https://forgejo.vcp.local>

Raw OrbStack hostnames still exist, but they are not the main operator path.
The adapter under [orbstack-domains/](./orbstack-domains) maps the friendly
hostnames to the `vind` service upstreams.

If you want a public fallback instead, use:

- [cloudflare-tunnel.yaml](./cloudflare-tunnel.yaml)

## Secrets

After the cluster is up, continue with:

1. create the bootstrap secret `one-password-sa-token` in namespace `eso`
2. apply [eso-cluster-store.yaml](./eso-cluster-store.yaml)
3. apply [bootstrap-external-secrets.yaml](./bootstrap-external-secrets.yaml)
4. verify the initial secrets in `argocd`, `vcluster-platform`, and `crossplane-system`

The full secret contract is here:

- [docs/secret-contract.md](../docs/secret-contract.md)

## Lower-Level Helpers

Use these only when you want more manual control:

- [install-vind.sh](./install-vind.sh)
- [start-orbstack-domains.sh](./start-orbstack-domains.sh)
- [delete-vind.sh](./delete-vind.sh)
- [vcluster.yaml](./vcluster.yaml)

## Related Docs

- [vcluster-gitops/overlays/local-contained/README.md](../vcluster-gitops/overlays/local-contained/README.md)
- [scripts/README.md](../scripts/README.md)
- [vcluster-platform-demo-generator.md](../vcluster-platform-demo-generator.md)

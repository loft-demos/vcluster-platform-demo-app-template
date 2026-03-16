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
- enabled use cases: `eso`

What the bootstrap does:

- creates or upgrades the `vind` cluster
- installs vCluster Platform, Argo CD, ESO, and Forgejo
- annotates `clusters.management.loft.sh/loft-cluster` with `domainPrefix`, `domain`, and `sleepTimeZone`
- runs local placeholder replacement
- pushes the repo into Forgejo
- builds and pushes the `src/` demo image to the Forgejo container registry
- creates the Argo CD Forgejo secrets
- updates the Argo CD `cluster-local` secret that controls which use-case appsets are selected
- creates a default vCP `ProjectSecret` for registry auth in `p-default`
- applies the root Argo CD `Application`
- starts the OrbStack domain adapter

The root Argo CD app is:

- [root-application.yaml](../vcluster-gitops/overlays/local-contained/root-application.yaml)

## Forgejo Instead of GitHub

The self-contained `vind` path uses Forgejo as the local replacement for both
GitHub and most of the GHCR-dependent flow.

In practice that means:

- this repo is pushed into Forgejo instead of relying on a GitHub template copy
- Argo CD reads the repo from the in-cluster Forgejo service URL
- browser-facing links still use <https://forgejo.vcp.local>
- the demo app image from `src/` is built and pushed to the Forgejo container
  registry
- the bootstrap creates a default Platform `ProjectSecret` with Forgejo
  registry credentials for image pulls

Current intent for the self-contained path:

- PR examples should eventually build and pull images from the Forgejo registry
  instead of GHCR
- [vcluster-use-cases/auto-snapshots](../vcluster-use-cases/auto-snapshots)
  now renders to the Forgejo OCI registry in the self-contained path instead of
  GHCR, so it does not require S3 just for the local demo setup

> [!IMPORTANT]
> The Git hosting flow is the primary path and is the part that has been worked
> through the most. The Forgejo container registry path is wired into the
> bootstrap, including the self-contained auto-snapshots manifests, but it has
> not been validated as thoroughly yet as the Git side.

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

Enable a few use cases as part of the bootstrap:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --use-cases eso,auto-snapshots,flux
```

Enable almost everything except the heavier ones:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --use-cases all,-crossplane,-rancher
```

List the supported use cases:

```bash
bash vind-demo-cluster/bootstrap-self-contained.sh --list-use-cases
```

The demo image build runs in the background by default so the bootstrap can
finish faster. Use `--wait-for-image-build` if you want the script to block
until the Forgejo registry push completes.

On Apple Silicon, the image build now defaults to native `linux/arm64` instead
of forcing `linux/amd64`.

If you need to override that, use:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --image-platform linux/amd64
```

### Override the vCluster Platform Version

The default vCluster Platform chart version for the self-contained `vind` path
is `4.7.1`.

Use `--vcp-version` to override it, for example:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --vcp-version 4.8.0-rc.5
```

Delete the environment cleanly:

```bash
bash vind-demo-cluster/delete-vind.sh
```

> [!WARNING]
> `delete-vind.sh` also stashes local repo changes by default so the clone can
> be refreshed from `origin` without committing bootstrap mutations first.

Use a different vCP project namespace for the registry `ProjectSecret`:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --image-pull-project-namespace p-demos
```

## Local Access

Default local hostnames:

- <https://vcp.local>
- <https://argocd.vcp.local>
- <https://forgejo.vcp.local>

This setup uses a small [Caddy adapter](https://caddyserver.com/docs/quick-starts/reverse-proxy) under [orbstack-domains/](./orbstack-domains) because `vind` and OrbStack solve two different parts of the problem:

- `vind` creates `LoadBalancer` services for things like vCluster Platform,
  Argo CD, and Forgejo
- those `LoadBalancer` services are backed by HAProxy containers on the
  per-cluster Docker network, for example `vcluster.vcp`
- OrbStack can give nice local HTTPS hostnames to containers
- Caddy is the bridge that lets those OrbStack hostnames proxy to the `vind`
  `LoadBalancer` upstreams

That gives you friendly local URLs like `vcp.local` instead of relying on:

- raw OrbStack control-plane domains like `vcluster.cp.vcp.orb.local`
- raw `LoadBalancer` hostnames or local IPs

Raw OrbStack hostnames still exist, but they are not the main operator path.

For the full pattern, see:

- [orbstack-domains/README.md](./orbstack-domains/README.md)

If you want a public fallback instead, use:

- [cloudflare-tunnel.yaml](./cloudflare-tunnel.yaml)

## Cluster Annotations

Some Platform-side apps in this repo read host and timezone values from the
vCP `Cluster` resource, not from Argo CD.

The bootstrap annotates `clusters.management.loft.sh/loft-cluster` with:

- `domainPrefix`
- `domain`
- `sleepTimeZone`

For the default `vcp.local` setup, that becomes:

- `domainPrefix=vcp`
- `domain=local`
- `sleepTimeZone=America/New_York`

That is what keeps things like Helm Dashboard ingress hosts rendering as
`<name>.vcp.local` instead of an empty suffix.

## Use Case Selection

The Argo CD app-of-apps layer uses the `argocd/cluster-local` secret to decide
which use-case `ApplicationSet`s should match the local `vind` cluster.

The bootstrap manages that secret for you. Use:

- `--use-cases default`
- `--use-cases eso,auto-snapshots,flux`
- `--use-cases all,-crossplane,-rancher`

Available use cases for the `vind` bootstrap:

- `argocd-in-vcluster`
- `auto-snapshots`
- `connected-host-cluster`
- `crossplane`
- `eso`
- `flux`
- `kyverno`
- `mysql`
- `namespace-sync`
- `postgres`
- `rancher`
- `resolve-dns`
- `virtual-scheduler`
- `vnode`

The current default is intentionally small:

- `eso`

That keeps the self-contained path lighter and avoids turning on use cases that
still depend on extra secrets or infrastructure by default.

For the full use-case and feature list, see:

- [top-level README use-case index](../README.md#available-use-cases)

## Secrets

After the cluster is up, continue with:

1. create the bootstrap secret `one-password-sa-token` in namespace `eso`
2. apply [eso-cluster-store.yaml](./eso-cluster-store.yaml)
3. apply [bootstrap-external-secrets.yaml](./bootstrap-external-secrets.yaml)
4. verify the initial secrets in `argocd`, `vcluster-platform`, and `crossplane-system`

The full secret contract is here:

- [docs/secret-contract.md](../docs/secret-contract.md)

The self-contained bootstrap also creates a default Platform `ProjectSecret`
for the Forgejo registry:

- name: `vcluster-demos-ghcr-write-pat`
- namespace: `p-default`
- label `loft.sh/project-secret-name`: `vcluster-demos-ghcr-write`
- data keys:
  - `username`
  - `password`

Override that with:

- `--image-pull-project-namespace`
- `--image-pull-project-secret-name`
- `--image-pull-source-secret-name`

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

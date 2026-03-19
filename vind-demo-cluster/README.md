# vind Demo Cluster

This folder is the self-contained path for this repo.

It uses:

- `vind` for the management cluster
- vCluster Platform, Argo CD, ESO, and Forgejo installed from [vcluster.yaml](./vcluster.yaml)
- OrbStack local domains for laptop access
- the local-contained GitOps overlay for the Argo CD bootstrap

## Prerequisites

Required:

- macOS with [OrbStack](https://orbstack.dev/) available
- `vcluster` CLI `0.33.0+`
- `kubectl` compatible with Kubernetes `1.35`
- `helm` `v3.10+`
- OrbStack's Docker runtime and `docker` CLI available
- a vCluster Platform `LICENSE_TOKEN`
- network access to:
  - `ghcr.io`
  - `charts.loft.sh`
  - `code.forgejo.org`

Recommended:

- an OrbStack Pro license, since the `vind` path assumes OrbStack is the local
  virtualization and domain layer
- `jq`, `yq`, `curl`, and `perl`, which the bootstrap scripts use directly

Optional, depending on the features you enable:

- `GHCR_USERNAME` and `GHCR_TOKEN` or `GHCR_PASSWORD` for the auto-snapshots use case
- a 1Password service account token if you want to finish the ESO setup after bootstrap

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
- optionally creates a default vCP `ProjectSecret` for snapshot registry auth in `p-default`
- applies the root Argo CD `Application`
- starts the OrbStack domain adapter
- when `private-nodes` is enabled, creates a default OrbStack Ubuntu VM named
  `private-node-demo-worker-1` for the manual worker-node join flow in the
  background
- adds vCluster Platform navbar links for the Forgejo GitOps repo and, when
  `flux` is enabled, the Flux UI

The root Argo CD app is:

- [root-application.yaml](../vcluster-gitops/overlays/local-contained/root-application.yaml)

## Forgejo Instead of GitHub

The self-contained `vind` path uses Forgejo as the local replacement for GitHub
and for the demo app image flow.

In practice that means:

- this repo is pushed into Forgejo instead of relying on a GitHub template copy
- Argo CD reads the repo from the in-cluster Forgejo service URL
- browser-facing links still use <https://forgejo.vcp.local>
- the demo app image from `src/` is built and pushed to the Forgejo container
  registry as `<repo>-demo-app`, under the repo-scoped prefix
  `forgejo.vcp.local/<org>/<repo>/<repo>-demo-app`
- the bootstrap can also create a default Platform `ProjectSecret` for snapshot
  registry auth when GHCR credentials are provided
- the vCluster Platform UI includes a `Forgejo Repo` button that points at the
  Forgejo home page, which avoids the logged-out repo `404` path

Current intent for the self-contained path:

- PR examples should eventually build and pull images from the Forgejo registry
  instead of GHCR
- [vcluster-use-cases/auto-snapshots](../vcluster-use-cases/auto-snapshots)
  still uses GHCR for snapshots in the self-contained path, because the local
  `forgejo.vcp.local` certificate is not trusted by the in-cluster snapshot job

> [!IMPORTANT]
> The Git hosting flow is the primary path and is the part that has been worked
> through the most. Forgejo is the default Git host for `vind`, but snapshots
> currently stay on GHCR until there is a trusted local registry endpoint for
> the in-cluster snapshot client.

When `flux` is enabled in `--use-cases`, the vCluster Platform UI also gets a
`Flux UI` button that points at the shared Flux Operator web UI host for this
demo environment.

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

Enable the private-nodes flow and create the default OrbStack worker VM:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --use-cases eso,private-nodes
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
is `4.8.0`.

Use `--vcp-version` to override it, for example:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --vcp-version 4.8.1-rc.1
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

Create the snapshot registry `ProjectSecret` during bootstrap:

```bash
LICENSE_TOKEN="$TOKEN" \
GHCR_USERNAME="$GHCR_USERNAME" \
GHCR_TOKEN="$GHCR_TOKEN" \
bash vind-demo-cluster/bootstrap-self-contained.sh
```

Use a different 1Password vault for the ESO store:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --onepassword-vault team-a
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
- `database-connector`
- `namespace-sync`
- `private-nodes`
- `postgres`
- `rancher`
- `resolve-dns`
- `tenant-observability`
- `virtual-scheduler`
- `vnode`

When `private-nodes` is selected, the bootstrap also creates a default OrbStack
Ubuntu VM for the example `private-node-demo` vCluster instance:

- default VM: `private-node-demo-worker-1`
- override with `--private-node-vm-name`
- the VM creation runs in the background so the bootstrap does not block on the
  initial OrbStack boot
- final join still happens manually by copying the Private Nodes connect command
  from vCluster Platform and running it inside that VM

> [!IMPORTANT]
> `tenant-observability` has been validated on the OrbStack-backed `vind` path
> with the standard Central HostPath Mapper + Promtail design. The root
> [README](../README.md#available-use-cases) tracks current `vind` validation
> status for the use cases.

The current default is intentionally small:

- `eso`

That keeps the self-contained path lighter and avoids turning on use cases that
still depend on extra secrets or infrastructure by default.

For the full use-case and feature list, see:

- [top-level README use-case index](../README.md#available-use-cases)
- [manual `cluster-local` editing](../README.md#enable-use-cases-directly-with-cluster-local)

## Secrets

After the cluster is up, continue with:

1. create the bootstrap secret `one-password-sa-token` in namespace `eso`
2. apply [eso-cluster-store.yaml](./eso-cluster-store.yaml)
3. apply [bootstrap-external-secrets.yaml](./bootstrap-external-secrets.yaml)
4. verify the initial secrets in `argocd`, `vcluster-platform`, and `crossplane-system`

The default 1Password vault placeholder for this path is:

- `vcluster-demos`

Override it during bootstrap with:

- `--onepassword-vault`

The full secret contract is here:

- [docs/secret-contract.md](../docs/secret-contract.md)

The self-contained bootstrap can also create a default Platform `ProjectSecret`
for snapshot registry auth:

- name: `vcluster-demos-ghcr-write`
- namespace: `p-default`
- label `loft.sh/project-secret-name`: `vcluster-demos-ghcr-write`
- display name: `vcluster-demos-ghcr-write-pat`
- data keys:
  - `username`
  - `password`

That secret is only created when snapshot registry credentials are provided,
for example with:

- `GHCR_USERNAME`
- `GHCR_TOKEN`
- `GHCR_PASSWORD`

Override that with:

- `--image-pull-project-namespace`
- `--image-pull-project-secret-name` for the display name shown in Platform
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

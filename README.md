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
- demo image: pushed to `forgejo.vcp.local/vcluster-demos/vcp-gitops/vcp-gitops-demo-app`
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

## Available Use Cases

`vCP Free` below is based on the official feature comparison and free-tier overview:

- [Compare pricing tiers](https://www.vcluster.com/docs/platform/free-vs-enterprise)
- [vCluster Free announcement](https://www.vcluster.com/blog/launching-vcluster-free-get-enterprise-features-at-no-cost)

`Yes` means the use case maps to features explicitly called out as available in the Free plan. `Enterprise` means it depends on features documented outside the Free plan. `Depends` means the repo example is mostly built from apps, templates, or external tooling and is not mapped cleanly to one specific line item in the pricing table.

| Use case | What it demos | vCP Free | `vind` | Details / docs |
| --- | --- | --- | --- | --- |
| `argocd-in-vcluster` | Installs a dedicated Argo CD instance inside selected vCluster instances and feeds it Git-based values. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/argocd-in-vcluster/README.md), [vCP Argo CD integration](https://www.vcluster.com/docs/platform/integrations/argocd) |
| `argocd-vcluster-add-ons` | Applies environment-specific add-ons to imported Argo CD clusters based on cluster labels like `dev`, `qa`, and `prod`. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/argocd-vcluster-add-ons/README.md), [vCP Argo CD integration](https://www.vcluster.com/docs/platform/integrations/argocd) |
| `argocd-vcluster-pull-request-environments` | Creates ephemeral pull request environments with Argo CD, including preview apps and vCluster instances per PR. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/argocd-vcluster-pull-request-environments/README.md), [vCP Argo CD integration](https://www.vcluster.com/docs/platform/integrations/argocd) |
| `auto-snapshots` | Automatic backup and restore of vCluster instances to an OCI registry such as GHCR or Forgejo. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/auto-snapshots/README.md), [Snapshots](https://www.vcluster.com/docs/platform/use-platform/virtual-clusters/key-features/snapshots) |
| `central-admission-control` | Centralized policy enforcement with Kyverno and host-level admission control for virtual clusters. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/central-admission-control/) |
| `connected-host-cluster` | Registers another cluster, or another vCluster instance, as an additional host cluster for vCluster Platform. | `Yes` | `TBD` | [Repo](./vcluster-use-cases/connected-host-cluster/README.md), [Connect a cluster](https://www.vcluster.com/docs/platform/next/administer/clusters/connect-cluster) |
| `crossplane` | Crossplane providers, compositions, and claims used for webhook automation and PR environment orchestration. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/crossplane/README.md) |
| `custom-resource-definitions` | Reserved area for CRD-focused demos and examples that depend on installing or exposing custom resource definitions. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/custom-resource-definitions/) |
| `custom-resource-sync` | Syncs custom resources such as Postgres operator objects between the host and the vCluster side. | `Yes` | `TBD` | [Repo](./vcluster-use-cases/custom-resource-sync/), [Custom resources to host](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/to-host/advanced/custom-resources) |
| `database-connector` | Uses the vCluster Platform database connector with MySQL as an external backing store for vCluster instances. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/database-connector/README.md), [Database connector](https://www.vcluster.com/docs/platform/administer/connector/database) |
| `external-secrets-operator` | Installs ESO and shows how to integrate external secret delivery into vCluster and Platform flows. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/external-secrets-operator/README.md), [External Secrets integration](https://www.vcluster.com/docs/vcluster/integrations/external-secrets/external-secrets) |
| `flux` | Flux Operator, Flux-managed vCluster instances, and Flux-based pull request environments. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/flux/README.md) |
| `kai-scheduler` | Runs vCluster workloads against a host-installed KAI scheduler instead of the default scheduling path. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/kai-scheduler/shared-from-host/README.md) |
| `namespace-sync` | Namespace sync plus Argo CD `Application` sync back to the host cluster. | `Yes` | `TBD` | [Repo](./vcluster-use-cases/namespace-sync/README.md), [Namespace sync](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/to-host/advanced/namespaces) |
| `pod-identity` | EKS Pod Identity with synced `PodIdentityAssociation` resources for AWS access from workloads in a vCluster. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/pod-identity/eks/README.md) |
| `pod-security-standards` | Enforces Pod Security Standards inside the vCluster API server with an admission configuration. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/pod-security-standards/README.md) |
| `private-nodes` | Manual Private Nodes flow for attaching dedicated external compute to a vCluster instance, including an OrbStack VM path for `vind`. | `Yes` | `TBD` | [Repo](./vcluster-use-cases/private-nodes/README.md) |
| `rancher-integration` | Rancher integration examples for deploying and wiring Rancher alongside vCluster Platform. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/rancher-integration/) |
| `resolve-dns` | Cross-vCluster DNS resolution with embedded CoreDNS and `resolveDNS` mappings. | `Yes` | `TBD` | [Repo](./vcluster-use-cases/resolve-dns/README.md), [Resolve DNS](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/networking/resolve-dns) |
| `tenant-observability` | Tenant-scoped Grafana, Loki, and Prometheus inside each vCluster, using CHPM + Promtail on the supported path. | `Enterprise` | `No` | [Repo](./vcluster-use-cases/tenant-observability/README.md), [Central HostPath Mapper](https://www.vcluster.com/docs/platform/maintenance/monitoring/central-hostpath-mapper) |
| `virtual-scheduler` | Enables the Kubernetes scheduler, or other schedulers, inside a vCluster. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/virtual-scheduler/README.md), [Sync nodes from host](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/from-host/nodes) |
| `vnode-with-vcluster` | Uses vNode with vCluster for stronger workload isolation and breakout demos. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/vnode-with-vcluster/README.md), [vNode docs](https://www.vnode.com/docs) |

`vind` above is the current self-contained OrbStack-backed path:

- `No` means the use case is currently not supported on `vind`
- `TBD` means it has not been fully validated on `vind` yet

## Enable Use Cases Directly with `cluster-local`

Both the Demo Generator path and the self-contained `vind` path use the Argo CD
cluster secret named `cluster-local` in namespace `argocd` to decide which
use-case `ApplicationSet`s should match the local management cluster.

That means you can enable or disable use cases directly with `kubectl label`
without rerunning the full bootstrap.

Example:

```bash
kubectl -n argocd label secret cluster-local \
  eso=true \
  autoSnapshots=true \
  flux=true \
  crossplane=false \
  rancher=false \
  --overwrite
```

Disable a use case:

```bash
kubectl -n argocd label secret cluster-local postgres=false --overwrite
```

Enable a few more use cases with the exact label keys:

```bash
kubectl -n argocd label secret cluster-local \
  argoCdInVcluster=true \
  connectedHostCluster=true \
  namespaceSync=true \
  privateNodes=true \
  resolveDNS=true \
  tenantObservability=true \
  virtualScheduler=true \
  --overwrite
```

Typical flow:

1. connect `kubectl` to the demo environment management cluster
2. update one or more labels on `argocd/cluster-local`
3. wait for Argo CD to refresh the matching `ApplicationSet`s and `Application`s

The label keys currently used by the repo are:

| Use case | `cluster-local` label |
| --- | --- |
| `argocd-in-vcluster` | `argoCdInVcluster` |
| `auto-snapshots` | `autoSnapshots` |
| `connected-host-cluster` | `connectedHostCluster` |
| `crossplane` | `crossplane` |
| `eso` | `eso` |
| `flux` | `flux` |
| `kyverno` | `kyverno` |
| `mysql` | `mysql` |
| `namespace-sync` | `namespaceSync` |
| `private-nodes` | `privateNodes` |
| `postgres` | `postgres` |
| `rancher` | `rancher` |
| `resolve-dns` | `resolveDNS` |
| `tenant-observability` | `tenantObservability` |
| `virtual-scheduler` | `virtualScheduler` |
| `vnode` | `vnode` |

Notes:

- on the `vind` path, the bootstrap `--use-cases` flag writes these labels for you
- on the Demo Generator path, the initial values usually come from template parameters and the generated cluster secret
- changing the secret directly is the fastest way to test another combination after the environment already exists

For the self-contained path, the Argo CD root app is:

- [root-application.yaml](./vcluster-gitops/overlays/local-contained/root-application.yaml)

The self-contained Git overlay is:

- [vcluster-gitops/overlays/local-contained/README.md](./vcluster-gitops/overlays/local-contained/README.md)

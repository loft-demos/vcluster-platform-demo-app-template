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
- [docs/self-service-enablement/README.md](./docs/self-service-enablement/README.md): enablement demo flow for self-service provisioning, project multi-tenancy, and RBAC
- [docs/secret-contract.md](./docs/secret-contract.md): secret contract for ESO / 1Password

## Available Use Cases

`vCP Free` below is based on the official feature comparison and free-tier overview:

- [Compare pricing tiers](https://www.vcluster.com/docs/platform/free-vs-enterprise)
- [vCluster Free announcement](https://www.vcluster.com/blog/launching-vcluster-free-get-enterprise-features-at-no-cost)

`Yes` means the use case maps to features explicitly called out as available in the Free plan. `Enterprise` means it depends on features documented outside the Free plan. `Depends` means the repo example is mostly built from apps, templates, or external tooling and is not mapped cleanly to one specific line item in the pricing table.

| Use case | What it demos | vCP Free | `vind` | Details / docs |
| --- | --- | --- | --- | --- |
| [`argocd-in-vcluster`](./vcluster-use-cases/argocd-in-vcluster/) | Installs a dedicated Argo CD instance inside selected vCluster instances and feeds it Git-based values. | `Enterprise` | `Yes` | [Repo](./vcluster-use-cases/argocd-in-vcluster/README.md), [vCP Argo CD integration](https://www.vcluster.com/docs/platform/integrations/argocd) |
| [`argocd-vcluster-add-ons`](./vcluster-use-cases/argocd-vcluster-add-ons/) | Applies environment-specific add-ons to imported Argo CD clusters based on cluster labels like `dev`, `qa`, and `prod`. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/argocd-vcluster-add-ons/README.md), [vCP Argo CD integration](https://www.vcluster.com/docs/platform/integrations/argocd) |
| [`argocd-vcluster-pull-request-environments`](./vcluster-use-cases/argocd-vcluster-pull-request-environments/) | Creates ephemeral pull request environments with Argo CD, including preview apps and vCluster instances per PR. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/argocd-vcluster-pull-request-environments/README.md), [vCP Argo CD integration](https://www.vcluster.com/docs/platform/integrations/argocd) |
| [`auto-nodes`](./vcluster-use-cases/private-nodes/auto-nodes/) | Auto-provisions pod-backed worker nodes for vCluster instances using the vCluster Platform Auto Nodes feature and the pod-node Terraform provider. | `Enterprise` | `Yes` | [Repo](./vcluster-use-cases/private-nodes/auto-nodes/) |
| [`auto-snapshots`](./vcluster-use-cases/auto-snapshots/) | Automatic backup and restore of vCluster instances to S3-compatible storage (MinIO for vind). | `Enterprise` | `No*` | [Repo](./vcluster-use-cases/auto-snapshots/README.md), [Snapshots](https://www.vcluster.com/docs/platform/use-platform/virtual-clusters/key-features/snapshots) |
| [`central-admission-control`](./vcluster-use-cases/central-admission-control/) | Centralized policy enforcement with Kyverno and host-level admission control for virtual clusters. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/central-admission-control/) |
| [`connected-host-cluster`](./vcluster-use-cases/connected-host-cluster/) | Registers another cluster, or another vCluster instance, as an additional host cluster for vCluster Platform. | `Yes` | `TBD` | [Repo](./vcluster-use-cases/connected-host-cluster/README.md), [Connect a cluster](https://www.vcluster.com/docs/platform/next/administer/clusters/connect-cluster) |
| [`continuous-promotion`](./vcluster-use-cases/continuous-promotion/) | Uses Kargo, Argo CD, sleeping vCluster instances, and a shared-node pre-prod gate where the app can consume host-managed ESO-backed config before promotion. | `Depends` | `Yes` | [Repo](./vcluster-use-cases/continuous-promotion/README.md), [Kargo](https://docs.kargo.io) |
| [`crossplane`](./vcluster-use-cases/crossplane/) | Crossplane providers, compositions, and claims used for webhook automation and PR environment orchestration. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/crossplane/README.md) |
| [`custom-resource-definitions`](./vcluster-use-cases/custom-resource-definitions/) | Reserved area for CRD-focused demos and examples that depend on installing or exposing custom resource definitions. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/custom-resource-definitions/) |
| [`custom-resource-sync`](./vcluster-use-cases/custom-resource-sync/) | Syncs CloudNative PG `Cluster` resources from a vCluster to a host-side CNPG operator. | `Yes` | `TBD` | [Repo](./vcluster-use-cases/custom-resource-sync/), [Custom resources to host](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/to-host/advanced/custom-resources) |
| [`database-connector`](./vcluster-use-cases/database-connector/) | Uses the vCluster Platform database connector with CloudNative PG as an external backing store for vCluster instances. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/database-connector/README.md), [Database connector](https://www.vcluster.com/docs/platform/administer/connector/database) |
| [`external-secrets-operator`](./vcluster-use-cases/external-secrets-operator/) | Installs ESO and shows how to integrate external secret delivery into vCluster and Platform flows. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/external-secrets-operator/README.md), [External Secrets integration](https://www.vcluster.com/docs/vcluster/integrations/external-secrets/external-secrets) |
| [`flux`](./vcluster-use-cases/flux/) | Flux Operator, Flux-managed vCluster instances, and Flux-based pull request environments. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/flux/README.md) |
| [`kai-scheduler`](./vcluster-use-cases/kai-scheduler/) | Runs vCluster workloads against a host-installed KAI scheduler instead of the default scheduling path. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/kai-scheduler/shared-from-host/README.md) |
| [`namespace-sync`](./vcluster-use-cases/namespace-sync/) | Namespace sync plus Argo CD `Application` sync back to the host cluster. | `Yes` | `TBD` | [Repo](./vcluster-use-cases/namespace-sync/README.md), [Namespace sync](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/to-host/advanced/namespaces) |
| [`pod-identity`](./vcluster-use-cases/pod-identity/) | EKS Pod Identity with synced `PodIdentityAssociation` resources for AWS access from workloads in a vCluster. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/pod-identity/eks/README.md) |
| [`pod-security-standards`](./vcluster-use-cases/pod-security-standards/) | Enforces Pod Security Standards inside the vCluster API server with an admission configuration. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/pod-security-standards/README.md) |
| [`private-nodes`](./vcluster-use-cases/private-nodes/) | Manual Private Nodes flow for attaching dedicated external compute to a vCluster instance, including an OrbStack VM path for `vind`. | `Yes` | `Yes` | [Repo](./vcluster-use-cases/private-nodes/README.md) |
| [`rancher-integration`](./vcluster-use-cases/rancher-integration/) | Rancher integration examples for deploying and wiring Rancher alongside vCluster Platform. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/rancher-integration/) |
| [`resolve-dns`](./vcluster-use-cases/resolve-dns/) | Cross-vCluster DNS resolution with embedded CoreDNS and `resolveDNS` mappings. | `Yes` | `TBD` | [Repo](./vcluster-use-cases/resolve-dns/README.md), [Resolve DNS](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/networking/resolve-dns) |
| [`tenant-observability`](./vcluster-use-cases/tenant-observability/) | Tenant-scoped Grafana, Loki, and Prometheus inside each vCluster using Central HostPath Mapper plus Promtail for log collection. | `Enterprise` | `Yes` | [Repo](./vcluster-use-cases/tenant-observability/README.md), [Central HostPath Mapper](https://www.vcluster.com/docs/platform/maintenance/monitoring/central-hostpath-mapper) |
| [`virtual-scheduler`](./vcluster-use-cases/virtual-scheduler/) | Enables the Kubernetes scheduler, or other schedulers, inside a vCluster. | `Depends` | `TBD` | [Repo](./vcluster-use-cases/virtual-scheduler/README.md), [Sync nodes from host](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/from-host/nodes) |
| [`vnode-with-vcluster`](./vcluster-use-cases/vnode-with-vcluster/) | Uses vNode with vCluster for stronger workload isolation and breakout demos. | `Enterprise` | `TBD` | [Repo](./vcluster-use-cases/vnode-with-vcluster/README.md), [vNode docs](https://www.vnode.com/docs) |

`vind` above is the current self-contained OrbStack-backed path:

- `Yes` means the use case has been validated on `vind`
- `TBD` means it has not been fully validated on `vind` yet
- `No*` means the overlay code exists but the use case is temporarily disabled due to an upstream blocker

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
kubectl -n argocd label secret cluster-local customResourceSync=false --overwrite
```

Enable a few more use cases with the exact label keys:

```bash
kubectl -n argocd label secret cluster-local \
  argoCdInVcluster=true \
  customResourceSync=true \
  cnpg=true \
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
| `auto-nodes` | `autoNodes` |
| `auto-snapshots` | `autoSnapshots` |
| `connected-host-cluster` | `connectedHostCluster` |
| `continuous-promotion` | `continuousPromotion` |
| `crossplane` | `crossplane` |
| `custom-resource-sync` | `customResourceSync` |
| `eso` | `eso` |
| `flux` | `flux` |
| `kyverno` | `kyverno` |
| `database-connector` | `databaseConnector` |
| `namespace-sync` | `namespaceSync` |
| `private-nodes` | `privateNodes` |
| `rancher` | `rancher` |
| `resolve-dns` | `resolveDNS` |
| `tenant-observability` | `tenantObservability` |
| `virtual-scheduler` | `virtualScheduler` |
| `vnode` | `vnode` |

Additional behavior toggle:

| Purpose | `cluster-local` label |
| --- | --- |
| install the shared host-side CNPG operator for `database-connector` and `custom-resource-sync` | `cnpg` |
| opt into the legacy Argo CD-managed Kargo install for `continuous-promotion` | `legacyArgoKargo` |

Notes:

- on the `vind` path, the bootstrap `--use-cases` flag writes these labels for you
- on the `vind` path, `cnpg` is derived automatically when either `database-connector` or `custom-resource-sync` is enabled
- if you edit `argocd/cluster-local` manually, set `cnpg=true` whenever either `databaseConnector=true` or `customResourceSync=true`
- on the `vind` self-contained path, `legacyArgoKargo` is derived automatically when `continuous-promotion` is enabled without `flux`, so you do not need to set that label by hand
- on the Demo Generator path, the initial values usually come from template parameters and the generated cluster secret
- changing the secret directly is the fastest way to test another combination after the environment already exists

For the self-contained path, the Argo CD root app is:

- [root-application.yaml](./vcluster-gitops/overlays/local-contained/root-application.yaml)

The self-contained Git overlay is:

- [vcluster-gitops/overlays/local-contained/README.md](./vcluster-gitops/overlays/local-contained/README.md)

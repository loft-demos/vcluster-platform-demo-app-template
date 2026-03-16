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
- demo image: pushed to `forgejo.vcp.local/vcluster-demos/vcp-gitops`
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

| Use case | What it demos | Details / docs |
| --- | --- | --- |
| `argocd-in-vcluster` | Installs a dedicated Argo CD instance inside selected vCluster instances and feeds it Git-based values. | [Repo](./vcluster-use-cases/argocd-in-vcluster/README.md), [vCP Argo CD integration](https://www.vcluster.com/docs/platform/integrations/argocd) |
| `argocd-vcluster-add-ons` | Applies environment-specific add-ons to imported Argo CD clusters based on cluster labels like `dev`, `qa`, and `prod`. | [Repo](./vcluster-use-cases/argocd-vcluster-add-ons/README.md), [vCP Argo CD integration](https://www.vcluster.com/docs/platform/integrations/argocd) |
| `argocd-vcluster-pull-request-environments` | Creates ephemeral pull request environments with Argo CD, including preview apps and vCluster instances per PR. | [Repo](./vcluster-use-cases/argocd-vcluster-pull-request-environments/README.md), [vCP Argo CD integration](https://www.vcluster.com/docs/platform/integrations/argocd) |
| `auto-snapshots` | Automatic backup and restore of vCluster instances to an OCI registry such as GHCR or Forgejo. | [Repo](./vcluster-use-cases/auto-snapshots/README.md), [Snapshots](https://www.vcluster.com/docs/platform/use-platform/virtual-clusters/key-features/snapshots) |
| `central-admission-control` | Centralized policy enforcement with Kyverno and host-level admission control for virtual clusters. | [Repo](./vcluster-use-cases/central-admission-control/) |
| `connected-host-cluster` | Registers another cluster, or another vCluster instance, as an additional host cluster for vCluster Platform. | [Repo](./vcluster-use-cases/connected-host-cluster/README.md), [Connect a cluster](https://www.vcluster.com/docs/platform/next/administer/clusters/connect-cluster) |
| `crossplane` | Crossplane providers, compositions, and claims used for webhook automation and PR environment orchestration. | [Repo](./vcluster-use-cases/crossplane/README.md) |
| `custom-resource-definitions` | Reserved area for CRD-focused demos and examples that depend on installing or exposing custom resource definitions. | [Repo](./vcluster-use-cases/custom-resource-definitions/) |
| `custom-resource-sync` | Syncs custom resources such as Postgres operator objects between the host and the vCluster side. | [Repo](./vcluster-use-cases/custom-resource-sync/), [Custom resources to host](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/to-host/advanced/custom-resources) |
| `database-connector` | Uses the vCluster Platform database connector with MySQL as an external backing store for vCluster instances. | [Repo](./vcluster-use-cases/database-connector/README.md), [Database connector](https://www.vcluster.com/docs/platform/administer/connector/database) |
| `external-secrets-operator` | Installs ESO and shows how to integrate external secret delivery into vCluster and Platform flows. | [Repo](./vcluster-use-cases/external-secrets-operator/README.md), [External Secrets integration](https://www.vcluster.com/docs/vcluster/integrations/external-secrets/external-secrets) |
| `flux` | Flux Operator, Flux-managed vCluster instances, and Flux-based pull request environments. | [Repo](./vcluster-use-cases/flux/README.md) |
| `kai-scheduler` | Runs vCluster workloads against a host-installed KAI scheduler instead of the default scheduling path. | [Repo](./vcluster-use-cases/kai-scheduler/shared-from-host/README.md) |
| `namespace-sync` | Namespace sync plus Argo CD `Application` sync back to the host cluster. | [Repo](./vcluster-use-cases/namespace-sync/README.md), [Namespace sync](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/to-host/advanced/namespaces) |
| `pod-identity` | EKS Pod Identity with synced `PodIdentityAssociation` resources for AWS access from workloads in a vCluster. | [Repo](./vcluster-use-cases/pod-identity/eks/README.md) |
| `pod-security-standards` | Enforces Pod Security Standards inside the vCluster API server with an admission configuration. | [Repo](./vcluster-use-cases/pod-security-standards/README.md) |
| `private-nodes` | Attaches dedicated external compute to a vCluster instance with Private Nodes and auto-node patterns. | [Repo](./vcluster-use-cases/private-nodes/README.md) |
| `rancher-integration` | Rancher integration examples for deploying and wiring Rancher alongside vCluster Platform. | [Repo](./vcluster-use-cases/rancher-integration/) |
| `resolve-dns` | Cross-vCluster DNS resolution with embedded CoreDNS and `resolveDNS` mappings. | [Repo](./vcluster-use-cases/resolve-dns/README.md), [Resolve DNS](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/networking/resolve-dns) |
| `virtual-scheduler` | Enables the Kubernetes scheduler, or other schedulers, inside a vCluster. | [Repo](./vcluster-use-cases/virtual-scheduler/README.md), [Sync nodes from host](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/from-host/nodes) |
| `vnode-with-vcluster` | Uses vNode with vCluster for stronger workload isolation and breakout demos. | [Repo](./vcluster-use-cases/vnode-with-vcluster/README.md), [vNode docs](https://www.vnode.com/docs) |

For the self-contained path, the Argo CD root app is:

- [root-application.yaml](./vcluster-gitops/overlays/local-contained/root-application.yaml)

The self-contained Git overlay is:

- [vcluster-gitops/overlays/local-contained/README.md](./vcluster-gitops/overlays/local-contained/README.md)

Notes:

- use `vCluster instances` or `virtual clusters` in public docs
- `0.32.0+` template sleep and deletion config in this repo has already been updated

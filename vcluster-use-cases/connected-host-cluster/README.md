# Connected Host Cluster

This use case bootstraps a separate Kubernetes cluster as a **connected host cluster** for vCluster Platform by deploying the vCluster Platform Helm chart in `agentOnly` mode into that remote cluster.

In the demo-generator flow, that connected host cluster is not an arbitrary external Kubernetes cluster. It is a vCluster instance provisioned by the vCP Demo Generator from the upstream `connected-host-cluster-template`, and then registered back into the management plane as a connected host cluster target for additional vCluster Platform workloads.

The files in this folder are split into three stages:

1. Argo CD deploys the manifests in [`apps/`](./apps/)
2. Those manifests create a kubeconfig `Secret` placeholder and a Flux `Kustomization` from [`manifests/`](./manifests/)
3. Flux then applies the resources in [`flux-kustomize-manifests/`](./flux-kustomize-manifests/) to the remote connected cluster

## Folder Layout

```text
vcluster-use-cases/connected-host-cluster/
├── apps/
│   └── connected-host-cluster-manifests.yaml
├── manifests/
│   ├── connected-cluster-kube-config-secret.yaml
│   └── flux-kustomization.yaml
└── flux-kustomize-manifests/
    ├── access-key.yaml
    ├── connected-cluster.yaml
    ├── kustomization.yaml
    └── vcp-helm.yaml
```

## What Each Folder Does

### `apps/`

[`apps/connected-host-cluster-manifests.yaml`](./apps/connected-host-cluster-manifests.yaml) defines the Argo CD `Application` that applies the contents of the [`manifests/`](./manifests/) folder into the `p-vcluster-flux-demo` namespace.

This folder is intended to be targeted by the app-of-apps `ApplicationSet` defined in [`vcluster-gitops/argocd/app-of-apps/connected-host-cluster-appset.yaml`](../../vcluster-gitops/argocd/app-of-apps/connected-host-cluster-appset.yaml), which selects Argo CD clusters labeled:

```yaml
connectedHostCluster: "true"
```

### `manifests/`

This folder contains the resources Argo CD applies first:

- [`manifests/connected-cluster-kube-config-secret.yaml`](./manifests/connected-cluster-kube-config-secret.yaml) creates a placeholder `Secret` named `dev-cluster-kube-config` in `p-vcluster-flux-demo`. The secret is labeled with `loft.sh/project-secret-name`, so vCluster Platform can project the actual kubeconfig data from a project secret into this namespace.
- [`manifests/flux-kustomization.yaml`](./manifests/flux-kustomization.yaml) creates a Flux `Kustomization` named `connected-host-cluster-flux-kustomization` that points at `./vcluster-use-cases/connected-host-cluster/flux-kustomize-manifests`.

The Flux `Kustomization` also uses:

```yaml
postBuild:
  substituteFrom:
    - kind: Secret
      name: demo-admin-access-key
```

That means the `demo-admin-access-key` secret must exist in `p-vcluster-flux-demo` so Flux can substitute `${connectedHostClusterAccessKey}` into the rendered manifests.

### `flux-kustomize-manifests/`

This folder contains the resources Flux applies after the `Kustomization` is created.

[`flux-kustomize-manifests/kustomization.yaml`](./flux-kustomize-manifests/kustomization.yaml) includes:

- [`connected-cluster.yaml`](./flux-kustomize-manifests/connected-cluster.yaml) creates a vCluster Platform `Cluster` resource named `dev-cluster`
- [`access-key.yaml`](./flux-kustomize-manifests/access-key.yaml) creates a vCluster Platform `AccessKey` for the connected cluster agent
- [`vcp-helm.yaml`](./flux-kustomize-manifests/vcp-helm.yaml) installs the `vcluster-platform` Helm chart into the remote cluster using:
  - `agentOnly: true`
  - `token: "${connectedHostClusterAccessKey}"`
  - `kubeConfig.secretRef.name: dev-cluster-kube-config`

The Helm release targets the remote cluster referenced by the kubeconfig secret, not the local cluster where Argo CD and Flux are running.

## Bootstrap Flow

1. Argo CD targets the `apps/` folder for clusters labeled `connectedHostCluster=true`
2. The `Application` in `apps/` creates the secret placeholder and Flux `Kustomization` from `manifests/`
3. Flux reads the repo path `./vcluster-use-cases/connected-host-cluster/flux-kustomize-manifests`
4. Flux substitutes `${connectedHostClusterAccessKey}` from the `demo-admin-access-key` secret
5. Flux applies the `Cluster`, `AccessKey`, and `HelmRelease`
6. The Helm release installs the vCluster Platform agent into the remote cluster, connecting it back to the management plane

## Required Inputs and Placeholders

Before using this example, make sure the following values are available:

- `{REPLACE_ORG_NAME}` and `{REPLACE_REPO_NAME}` in the Argo CD `Application` source repo references
- `{REPLACE_VCLUSTER_NAME}` in the projected kubeconfig project secret label
- `{REPLACE_BASE_DOMAIN}` in [`flux-kustomize-manifests/vcp-helm.yaml`](./flux-kustomize-manifests/vcp-helm.yaml)
- A project secret named `vc-connected-host-cluster-{REPLACE_VCLUSTER_NAME}-connected-flux-kubeconfig` that provides the remote cluster kubeconfig
- A `demo-admin-access-key` secret in `p-vcluster-flux-demo` with a `connectedHostClusterAccessKey` value for Flux post-build substitution

## Notes

- In the vCP Demo Generator setup, the `dev-cluster` connected host cluster is a generated vCluster instance created from the upstream `connected-host-cluster-template`, rather than a manually provisioned remote cluster.
- The connected cluster is registered in vCluster Platform as `dev-cluster` by [`connected-cluster.yaml`](./flux-kustomize-manifests/connected-cluster.yaml).
- The Helm release currently pins `vcluster-platform` to `4.4.0-alpha.31`.
- The uninstall configuration in [`flux-kustomize-manifests/vcp-helm.yaml`](./flux-kustomize-manifests/vcp-helm.yaml) uses `deletionPropagation: orphan`, so deleting the Helm release will not aggressively clean up all remote resources.

Upstream references:

- Connected host cluster template: `https://github.com/loft-demos/loft-demo-base/blob/main/vcluster-platform-demo-generator/vcluster-platform-gitops/virtual-cluster-templates/connected-host-cluster-template.yaml`
- Demo generator overview: `https://github.com/loft-demos/loft-demo-base/blob/main/vcluster-platform-demo-generator/README.md`

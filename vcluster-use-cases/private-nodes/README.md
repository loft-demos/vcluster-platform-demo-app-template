# vCluster Private Nodes

This use case demonstrates the manual Private Nodes model for vCluster
Platform. The intent is:

- create a private-node-enabled vCluster
- provision an external machine yourself
- use the Private Nodes connect command to join that machine to the vCluster

For the `vind` path, OrbStack is the natural external-machine provider because
it is already a repo dependency.

## What This Uses

The included template:

- enables Private Nodes
- enables the vCluster VPN
- uses embedded etcd

Relevant manifests:

- [manifests/private-node-template.yaml](./manifests/private-node-template.yaml)
- [manifests/private-node-vcluster.yaml](./manifests/private-node-vcluster.yaml)

## Why VPN Is Enabled

For this demo, the private-node template enables:

```yaml
privateNodes:
  enabled: true
  vpn:
    enabled: true
    nodeToNode:
      enabled: true
```

That is the safer default for the `vind` + OrbStack VM path because the joined
VM does not need a separate public control-plane endpoint to reach the vCluster.

## OrbStack VM Flow for `vind`

Create an Ubuntu 24.04 OrbStack VM:

```bash
bash vcluster-use-cases/private-nodes/create-orbstack-private-node.sh
```

Or create a named VM and immediately run the Platform-generated connect command:

```bash
bash vcluster-use-cases/private-nodes/create-orbstack-private-node.sh \
  --machine private-node-a \
  --connect-command '<paste the connect command from vCluster Platform>'
```

Start the VM creation in the background instead of waiting for OrbStack boot:

```bash
bash vcluster-use-cases/private-nodes/create-orbstack-private-node.sh \
  --machine private-node-a \
  --background
```

This helper intentionally does not use cloud-init. The Private Nodes connect
command already handles the required node bootstrap.

## Demo Flow

1. enable the `private-nodes` use case through Argo CD
2. let Argo CD create the private-node template
3. create a vCluster from `private-node-demo-template`
4. create an OrbStack VM for the node
5. copy the Private Nodes connect command from the vCluster Platform UI
6. run that command inside the OrbStack VM

Example enablement:

```bash
kubectl -n argocd label secret cluster-local privateNodes=true --overwrite
```

For `vind`, include it in the selected use cases once that appset is wired:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --use-cases eso,private-nodes
```

In the `vind` bootstrap, the default OrbStack VM creation runs in the
background so the bootstrap does not wait for the initial VM boot.

## What Changed from the Older Cloud Auto-Node Example

This repo previously had a GCP/provider-shaped private-nodes template. For the
`vind` path, this use case is now focused on the manual join flow first.

The older provider artifacts are still present for follow-up work:

- [manifests/gcp-node-provider.yaml](./manifests/gcp-node-provider.yaml)

Auto Nodes can be added next as a separate step following the workshop model.

## Auto Nodes (vind only)

The `auto-nodes` sub-use-case in [`auto-nodes/`](./auto-nodes/) uses
[vcluster-auto-nodes-pod](https://github.com/loft-demos/vcluster-auto-nodes-pod)
— a Terraform-based `NodeProvider` that provisions pod-nodes (privileged pods
acting as kubelet worker nodes).

> **Cluster requirement:** Pod-nodes rely on nested container runtimes inside a
> privileged pod. This only works on **container-based clusters** such as `vind`
> or `kind`. It will not work on standard VM-based clusters (EKS, GKE, AKS,
> bare-metal) where the host does not support the required nesting.

Enable it during `vind` bootstrap:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --use-cases auto-nodes
```

# vCluster Namespace Sync with Argo CD Application Integration

This template demonstrates how to enable [vCluster's namespace syncing feature](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/to-host/advanced/namespaces) in combination with syncing Argo CD `Application` resources to the host cluster. It also patches each synced `Application` resource so that its `.spec.destination` points to the correct vCluster endpoint via the vCluster Platform proxy.

## Features

- **Namespace syncing**: Syncs specific virtual namespaces into matching host namespaces.
- **Custom Resource Sync**: Automatically syncs `applications.argoproj.io` resources to the host cluster.
- **Resource patching**: Ensures synced Argo CD `Application` resources target the vCluster control plane via the correct `destination.server` field.
- **Sleep mode**: Configurable auto-sleep for unused vClusters.

## Demo Use Case

A typical use case is when tenants create Argo CD `Application` resources inside their vCluster. This template allows those `Application` resources to appear in and be managed by a shared Argo CD instance running on the host cluster. This is achieved by syncing the virtual namespace to a dedicated physical namespace and patching the destination to route through the vCluster Platform's API proxy.

## Argo CD Requirements

Requires Argo CD multi-namespace mode to be enabled. Here is an example `values.yaml` configuration for the argo-cd Helm chart:

```yaml
configs:
  params:
  application.namespaces: "argo-apps-*"
  applicationsetcontroller.namespaces: "argo-apps-*"
```

## Template Overview

This vCluster template:

- Enables namespace syncing
- Defines exact mappings for synced namespaces
- Syncs Argo CD `Application` resources from the vCluster to the host
- Applies a patch to `.spec.destination` so Argo CD can manage them on the host
- Supports sleep mode for idle vCluster instances

### Example Patch Expression

```text
({ name: `loft-{{ .Values.loft.project }}-vcluster-{{ .Values.loft.virtualClusterName }}`, namespace: value?.namespace })
```

This ensures that Argo CD Applications synced to the host are routed back to the correct vCluster control plane.

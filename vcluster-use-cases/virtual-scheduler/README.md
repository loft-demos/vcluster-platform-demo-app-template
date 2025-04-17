# Using a Kubernetes Scheduler Inside a vCluster

By default, vCluster does not include a Kubernetes Scheduler as part of its control plane. However, by syncing real nodes into the vCluster and enabling the `controlPlane.advanced.virtualScheduler` vCluster will include the configured Kubernetes distributions Scheduler binary in the syncer container. This configuration also allows deploying third party or custom Kubernetes Schedulers as well.

The following vCluster configuration will enable the Kubernetes Scheduler inside the vCluster and allow the use of custom Kubernetes schedulers:

```yaml
controlPlane:
  advanced:
    virtualScheduler:
      enabled: true
sync:
  fromHost:
    nodes:
      enabled: true
```

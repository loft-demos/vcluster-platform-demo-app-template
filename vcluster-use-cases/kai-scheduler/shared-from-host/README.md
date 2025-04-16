# vCluster Workloads with KAI Shared from Host

Using a KAI scheduler deployed to the host cluster for vCluster workload pods is as easy as setting `.spec.schedulerName = kai-scheduler` on the vCluster workload `pod`. However, there is one small caveat related to the KAI Pod Grouper. The pod-grouper is a pod controller that watches for pods with `.spec.schedulerName = kai-scheduler`, climbs the owner chain for each new pod, and employs a "grouping" logic based on the topmost owner's `GroupVersionKind`.

By default, the owner for all vCluster workload pods (synced to the host cluster) is the vCluster control plane service. However, the Helm installed `ClusterRole` for the pod-grouper does not include permissions to watch or list `Service` resources. Therefore, either those permissions need to be added to the podgrouper `ClusterRole` or the host cluster owner reference for vCluster workloads must be disabled.

The vCluster workload `Pods` owner reference may be disabled with the following configuration:
```
experimental:
  syncSettings:
    setOwner: false
```
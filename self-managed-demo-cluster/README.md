# Using this Repository with a Self-Managed vCluster Platform Cluster

Although the configuration and use case examples in this repository are intended to be used with the fully automated and fully managed [vCluster Platform Demo Generator](../vcluster-platform-demo-generator.md) vCluster Platform demo environments, it is also possible to use this repository with self-managed (non-inception) vCluster Platform environments by following these steps:

- Install Argo CD into the same cluster where vCluster Platform is installed.
- Install Bootstrap Argo CD `Application`
  - **Either** install the [Argo CD vCluster Platform GitOps App](../vcluster-gitops/argo-cd-vcluster-gitops-application.yaml) - which will also install the [Argo CD App of Apps `Application`](../vcluster-gitops/argocd/app-of-apps.yaml)
  - **OR**, if you don't want the vCluster Platform GitOps, just install the [Argo CD App of Apps `Application`](../vcluster-gitops/argocd/app-of-apps.yaml) to get the use case examples
- _optional_ Create necessary vCluster Platform Project Secrets required by some of the example use cases
- Create an [Argo CD cluster `Secret`](./argocd-cluster-bootstrap-secret.yaml) with the labels configured to trigger the installation of the use case examples you want installed in your cluster and add it to your Argo CD namespace

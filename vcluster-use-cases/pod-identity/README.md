# Pod Identity

This folder contains pod-identity examples for cloud-provider integrations that
depend on syncing identity-related resources from the vCluster to the host.

Current example:

- [`eks/`](./eks/)
  demonstrates EKS Pod Identity using the ACK
  `PodIdentityAssociation` custom resource

That example covers:

- syncing `ServiceAccount` resources to the host
- syncing `PodIdentityAssociation` resources to the host
- patching the synced resource so it points at the translated host-side service
  account and namespace
- validating the setup with an S3 read/write test workload

Start here:

- [eks/README.md](./eks/README.md)
- [eks/ack-eks-controller-deployment.md](./eks/ack-eks-controller-deployment.md)

# Custom Resource Sync

This folder shows a custom-resource-sync pattern using
[CloudNative PG](https://cloudnative-pg.io/) (CNPG).

The host-side CNPG operator is installed by a shared Argo CD app whenever
either this use case or the [`database-connector`](../database-connector/README.md)
use case is enabled. This use case then applies a `VirtualClusterTemplate` that syncs
`clusters.postgresql.cnpg.io` resources from the vCluster to the host.

What is here:

- `apps/custom-resource-sync-manifests.yaml`
  applies the host-side `VirtualClusterTemplate` manifest for this use case
- `manifests/cnpg-vcluster-template.yaml`
  defines the `VirtualClusterTemplate` with CNPG custom resource sync enabled
- `examples/cnpg-minimal-cluster.yaml`
  is a sample CNPG `Cluster` custom resource to apply inside the vCluster

This is useful for demos where:

- the CNPG operator should stay on the host cluster
- tenants interact with custom resources from inside the vCluster
- synced CRs need to reconcile against host-side controllers

Related vCluster docs:

- [Custom resources to host](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/to-host/advanced/custom-resources)

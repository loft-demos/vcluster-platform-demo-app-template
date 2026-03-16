# Custom Resource Sync

This folder shows a custom-resource-sync pattern using the Zalando Postgres
Operator.

The example installs the operator on the host side and uses a
`VirtualClusterTemplate` that syncs `postgresqls.acid.zalan.do` resources from
the vCluster to the host.

What is here:

- `apps/postgres-helm-app.yaml`
  installs the Zalando Postgres Operator with Argo CD
- `manifests/postgres-operator-vcluster.yaml`
  defines the `VirtualClusterTemplate` with custom resource sync enabled
- `examples/acid-minimal-cluster.yaml`
  is a sample `postgresql` custom resource for the operator

This is useful for demos where:

- the operator should stay on the host cluster
- tenants interact with custom resources from inside the vCluster
- synced CRs need to reconcile against host-side controllers

Related vCluster docs:

- [Custom resources to host](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/sync/to-host/advanced/custom-resources)

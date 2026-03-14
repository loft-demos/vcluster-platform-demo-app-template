# MySQL Operator with the vCluster Platform Database Connector

This folder contains a database-backed vCluster example that uses the
[vCluster Platform Database Connector](https://www.vcluster.com/docs/platform/administer/connector/database)
to provision external MySQL backing stores for vCluster instances.

The overall flow is:

1. install the MySQL Operator
2. create an `InnoDBCluster`
3. register a shared-database connector secret in vCluster Platform
4. create a `VirtualClusterTemplate` that uses that connector for its backing
   store
5. create a `VirtualClusterInstance` from that template

## Folder Layout

```text
vcluster-use-cases/database-connector/
├── apps/
│   ├── mysql-helm-app.yaml
│   └── mysql-manifests.yaml
└── manifests/
    ├── database-connector-secret.yaml
    ├── database-connector-vcluster.yaml
    ├── db-connected-vcluster-template.yaml
    ├── innodb-cluster-creds.yaml
    └── innodb-cluster.yaml
```

## What Each Folder Does

### `apps/`

This folder contains the Argo CD `Application` resources used to bootstrap the
database connector example.

- [`apps/mysql-helm-app.yaml`](./apps/mysql-helm-app.yaml)
  installs the MySQL Operator Helm chart into the `mysql-operator` namespace
  and is currently pinned to chart version `2.2.3`
- [`apps/mysql-manifests.yaml`](./apps/mysql-manifests.yaml)
  applies the manifests that create the MySQL cluster, connector secret,
  template, and example vCluster instance

### `manifests/`

This folder contains the actual MySQL, connector, and vCluster Platform
resources.

#### MySQL Credentials and Cluster

- [`manifests/innodb-cluster-creds.yaml`](./manifests/innodb-cluster-creds.yaml)
  creates the `innodb-cluster-creds` secret in `mysql-operator`
  and expects the value to be projected from a project secret using the label
  `loft.sh/project-secret-name: innodb-cluster-creds`
- [`manifests/innodb-cluster.yaml`](./manifests/innodb-cluster.yaml)
  creates an `InnoDBCluster` named `mysql-cluster` with:
  - `instances: 3`
  - `router.instances: 1`
  - a `16Gi` PVC template for MySQL data

This MySQL cluster is the shared external database service that the platform
database connector points at.

#### Database Connector Secret

[`manifests/database-connector-secret.yaml`](./manifests/database-connector-secret.yaml)
creates a secret named `mysql-database-connector` in the
`vcluster-platform` namespace.

This secret is labeled:

- `loft.sh/project-secret-name: database-connector`
- `loft.sh/connector-type: shared-database`

That makes it available to vCluster Platform as a shared database connector
named `mysql-database-connector`.

#### Database-Backed vCluster Template

[`manifests/db-connected-vcluster-template.yaml`](./manifests/db-connected-vcluster-template.yaml)
defines the `db-connector-vcluster` `VirtualClusterTemplate`.

The versioned template (`1.0.0`) is the important one. It:

- runs vCluster chart `0.32.1`
- enables sleep mode after `30m`
- enables deletion after `500h`
- syncs `Ingress` resources, all `Secret` resources, and
  `innodbclusters.mysql.oracle.com`
- configures the vCluster backing store to use the external connector:

```yaml
controlPlane:
  backingStore:
    database:
      external:
        enabled: true
        connector: mysql-database-connector
```

This means each vCluster instance created from the template uses the platform
database connector instead of the default embedded SQLite or etcd backing store.

#### Example vCluster Instance

[`manifests/database-connector-vcluster.yaml`](./manifests/database-connector-vcluster.yaml)
creates an example `VirtualClusterInstance` named
`database-connector-vcluster` in the `p-default` project namespace.

It references:

- template: `db-connector-vcluster`
- template version: `1.0.x`
- cluster: `loft-cluster`
- parameters:
  - `k8sVersion: v1.31.6`
  - `env: dev`

## Bootstrap Flow

The intended deployment order is:

1. Argo CD installs the MySQL Operator from
   [`apps/mysql-helm-app.yaml`](./apps/mysql-helm-app.yaml)
2. Argo CD applies the resources under [`manifests/`](./manifests/)
3. The MySQL credentials secret is projected into `mysql-operator`
4. The `InnoDBCluster` is created
5. The `mysql-database-connector` secret is projected into
   `vcluster-platform`
6. vCluster Platform recognizes that secret as a shared database connector
7. The `db-connector-vcluster` template becomes usable
8. The example `VirtualClusterInstance` is created from that template
9. The resulting vCluster instance uses the shared MySQL service through the
   external database connector

## Required Inputs and Assumptions

Before this example will work, the following inputs must exist:

- a project secret named `innodb-cluster-creds` that provides the MySQL root
  credentials projected into `mysql-operator`
- a project secret named `database-connector` that provides the connector
  configuration projected into the `vcluster-platform` namespace
- a running vCluster Platform installation in the same management cluster
- a `loft-cluster` cluster reference available to the
  `VirtualClusterInstance`

## Notes

- The example syncs `innodbclusters.mysql.oracle.com` into the vCluster
  instance, which makes the MySQL custom resource visible from inside the
  database-backed vCluster instance.
- The template still uses `controlPlane.distro.k8s.version`, which is worth
  keeping in mind if you later do a broader template cleanup.
- [`apps/mysql-manifests.yaml`](./apps/mysql-manifests.yaml) currently points
  Argo CD at `vcluster-use-cases/vcluster-platform-database-connector/manifests`,
  while the folder in this repo is
  `vcluster-use-cases/database-connector/manifests`. This README describes the
  actual folder structure present in this repository.

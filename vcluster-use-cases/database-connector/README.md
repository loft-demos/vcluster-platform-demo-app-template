# CloudNative PG with the vCluster Platform Database Connector

This use case demonstrates how to use the vCluster Platform **Database Connector** feature
to provision external PostgreSQL backing stores for vCluster instances.

Instead of the default SQLite backend, each vCluster gets its own isolated database and
non-privileged user on a shared [CloudNative PG](https://cloudnative-pg.io/) (CNPG) cluster.

## Folder Layout

```text
vcluster-use-cases/database-connector/
├── apps/
│   ├── cnpg-helm-app.yaml
│   └── cnpg-manifests.yaml
└── manifests/
    ├── database-connector-secret.yaml
    ├── database-connector-vcluster.yaml
    ├── db-connected-vcluster-template.yaml
    ├── innodb-cluster-creds.yaml
    └── innodb-cluster.yaml
```

## What Each Folder Does

### `apps/`

- [`apps/cnpg-helm-app.yaml`](./apps/cnpg-helm-app.yaml)
  installs the CloudNative PG operator Helm chart (`cloudnative-pg`) into the
  `cnpg-system` namespace.
- [`apps/cnpg-manifests.yaml`](./apps/cnpg-manifests.yaml)
  applies the manifests that create the PostgreSQL cluster, connector secret,
  template, and example vCluster instance.

### `manifests/`

#### PostgreSQL Credentials and Cluster

- [`manifests/innodb-cluster-creds.yaml`](./manifests/innodb-cluster-creds.yaml)
  creates the `postgres-cluster-superuser` secret in `cnpg-system`
  (type `kubernetes.io/basic-auth`) used by CNPG to bootstrap the superuser.
- [`manifests/innodb-cluster.yaml`](./manifests/innodb-cluster.yaml)
  creates a CNPG `Cluster` named `postgres-cluster` with 1 instance and a `5Gi` PVC.

This PostgreSQL cluster is the shared external database service that the platform
database connector provisions isolated databases on for each vCluster.

#### Database Connector Secret

[`manifests/database-connector-secret.yaml`](./manifests/database-connector-secret.yaml)
creates a secret named `postgres-database-connector` in the `vcluster-platform` namespace.

The secret has the label `loft.sh/connector-type: shared-database` and contains
`endpoint`, `port`, `user`, `password`, and `type: postgres` fields.

#### Database-Backed vCluster Template

[`manifests/db-connected-vcluster-template.yaml`](./manifests/db-connected-vcluster-template.yaml)
defines the `db-connector-vcluster` `VirtualClusterTemplate`.

The versioned template configures the vCluster backing store to use the external connector:

```yaml
controlPlane:
  backingStore:
    database:
      external:
        enabled: true
        connector: postgres-database-connector
```

#### Example vCluster Instance

[`manifests/database-connector-vcluster.yaml`](./manifests/database-connector-vcluster.yaml)
creates an example `VirtualClusterInstance` named `database-connector-vcluster`
in the `p-default` project namespace using the `db-connector-vcluster` template.

## Secrets Contract

The `{REPLACE_DB_CONNECTOR_PASSWORD}` placeholder appears in both
`innodb-cluster-creds.yaml` and `database-connector-secret.yaml`.

- **vind / local path**: `scripts/replace-text-local.sh` substitutes the demo
  password (`vcluster-demo-postgres`) at bootstrap time.
- **Managed Generator path**: 1Password / ESO provides the real password via the
  project secret for the `vcluster-platform` namespace.

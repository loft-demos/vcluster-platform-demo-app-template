# CloudNative PG with the vCluster Platform Database Connector

This use case demonstrates how to use the vCluster Platform **Database Connector** feature to provision external PostgreSQL backing stores for vCluster instances.

Instead of the default SQLite backend, each vCluster gets its own isolated database and non-privileged user on a shared [CloudNative PG](https://cloudnative-pg.io/) (CNPG) cluster.

## Folder Layout

```text
vcluster-use-cases/database-connector/
├── apps/
│   └── cnpg-manifests.yaml
└── manifests/
    ├── cnpg-admin-secret.yaml
    ├── cnpg-cluster.yaml
    ├── database-connector-secret.yaml
    ├── database-connector-vcluster.yaml
    └── db-connected-vcluster-template.yaml
```

## What Each Folder Does

### `apps/`

- [`apps/cnpg-manifests.yaml`](./apps/cnpg-manifests.yaml) applies the manifests that create the PostgreSQL cluster, connector secret, template, and example vCluster instance.

The host-side CNPG operator itself is installed by a shared Argo CD app whenever either `database-connector` or `custom-resource-sync` is enabled.

### `manifests/`

#### PostgreSQL Admin Secret

[`manifests/cnpg-admin-secret.yaml`](./manifests/cnpg-admin-secret.yaml) creates a `Secret` named `cnpg-postgres-admin` in `cnpg-system` with the superuser credentials for the PostgreSQL cluster. The demo password is `vcluster-demo-postgres`.

For production use, replace this secret via your secret manager (1Password / ESO).

#### PostgreSQL Cluster

[`manifests/cnpg-cluster.yaml`](./manifests/cnpg-cluster.yaml) creates a CNPG `Cluster` named `postgres-cluster` with 1 instance and a `5Gi` PVC.

`enableSuperuserAccess: true` is required so CNPG allows superuser connections. `superuserSecret: cnpg-postgres-admin` pins the postgres superuser password to the known value in `cnpg-postgres-admin` rather than a CNPG-generated random password.

This PostgreSQL cluster is the shared external database service that the platform database connector provisions isolated databases on for each vCluster.

#### Database Connector Secret

[`manifests/database-connector-secret.yaml`](./manifests/database-connector-secret.yaml) creates a secret named `postgres-database-connector` in the `vcluster-platform` namespace.

The secret has the label `loft.sh/connector-type: shared-database` and contains `endpoint`, `port`, `user`, `password`, and `type: postgres` fields.

The `password` field is set to a placeholder at deploy time and patched by the bootstrap script after CNPG generates the superuser credentials (see **Secrets Contract** below).

#### Database-Backed vCluster Template

[`manifests/db-connected-vcluster-template.yaml`](./manifests/db-connected-vcluster-template.yaml) defines the `db-connector-vcluster` `VirtualClusterTemplate`.

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

[`manifests/database-connector-vcluster.yaml`](./manifests/database-connector-vcluster.yaml) creates an example `VirtualClusterInstance` named `database-connector-vcluster` in the `p-default` project namespace using the `db-connector-vcluster` template.

## Secrets Contract

`cnpg-postgres-admin` and `postgres-database-connector` share the same hardcoded demo password (`vcluster-demo-postgres`). CNPG reads `cnpg-postgres-admin` and sets the postgres superuser password to match, so the connector always authenticates.

**vind / local path**: no runtime patching needed. Both secrets are applied from git with the same password. Argo CD self-heal keeps them consistent automatically.

**Managed Generator path**: replace both secrets via 1Password / ESO with a real password before the environment is provisioned.

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
    ├── cnpg-cluster.yaml
    ├── database-connector-secret.yaml
    ├── database-connector-vcluster.yaml
    └── db-connected-vcluster-template.yaml
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

#### PostgreSQL Cluster

[`manifests/cnpg-cluster.yaml`](./manifests/cnpg-cluster.yaml)
creates a CNPG `Cluster` named `postgres-cluster` with 1 instance and a `5Gi` PVC.

CNPG auto-generates and manages the superuser credentials in the secret
`postgres-cluster-superuser` in the `cnpg-system` namespace.

This PostgreSQL cluster is the shared external database service that the platform
database connector provisions isolated databases on for each vCluster.

#### Database Connector Secret

[`manifests/database-connector-secret.yaml`](./manifests/database-connector-secret.yaml)
creates a secret named `postgres-database-connector` in the `vcluster-platform` namespace.

The secret has the label `loft.sh/connector-type: shared-database` and contains
`endpoint`, `port`, `user`, `password`, and `type: postgres` fields.

The `password` field is set to a placeholder at deploy time and patched by the bootstrap
script after CNPG generates the superuser credentials (see **Secrets Contract** below).

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

CNPG fully manages superuser credentials. The operator auto-generates the
`postgres-cluster-superuser` secret in `cnpg-system` with a random password.

**vind / local path**: `bootstrap-self-contained.sh` waits for CNPG to create
`postgres-cluster-superuser`, then patches `postgres-database-connector` in
`vcluster-platform` with the auto-generated password so vCP can authenticate.

**Managed Generator path**: 1Password / ESO reads `postgres-cluster-superuser`
and provides the credentials to `postgres-database-connector` in `vcluster-platform`.

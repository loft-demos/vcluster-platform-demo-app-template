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
    ├── cnpg-admin-secret.yaml
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

#### PostgreSQL Admin Secret

[`manifests/cnpg-admin-secret.yaml`](./manifests/cnpg-admin-secret.yaml)
creates a `Secret` named `cnpg-postgres-admin` in `cnpg-system` with the superuser
credentials for the PostgreSQL cluster.

The password field uses the `{REPLACE_DB_CONNECTOR_PASSWORD}` placeholder, which is
substituted by `scripts/replace-text-local.sh` (vind path) or your secret manager
(managed path) before the manifest is pushed to Git.

#### PostgreSQL Cluster

[`manifests/cnpg-cluster.yaml`](./manifests/cnpg-cluster.yaml)
creates a CNPG `Cluster` named `postgres-cluster` with 1 instance and a `5Gi` PVC.
It references `cnpg-postgres-admin` as the `superuserSecret` so CNPG uses the
pre-provisioned credentials rather than auto-generating a random password.

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

Both `cnpg-postgres-admin` (CNPG superuser) and `postgres-database-connector`
(vCP connector) share the same password via the `{REPLACE_DB_CONNECTOR_PASSWORD}`
placeholder. This avoids any runtime credential sync.

**vind / local path**: `scripts/replace-text-local.sh` substitutes the placeholder
with `vcluster-demo-postgres` (or a value passed via `--db-connector-password`) in
both secrets before the repo is pushed to Forgejo. No bootstrap patching is needed.

**Managed Generator path**: your secret manager (1Password / ESO) provides the same
password value for both `cnpg-postgres-admin` in `cnpg-system` and
`postgres-database-connector` in `vcluster-platform`.

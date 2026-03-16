# vCluster Automatic Snapshots

Snapshots are a built-in method to back up a vCluster as an OCI artifact that
can be pushed to either:

- an OCI-compliant container registry
- an S3 bucket

This demo configures a `VirtualClusterTemplate` and example
`VirtualClusterInstance` with snapshots configured under
`external.platform.autoSnapshot`.

## Registry Target By Deployment Mode

This use case now has two render paths:

- vCluster Platform Demo Generator / GitHub path:
  snapshots are pushed to GHCR
- self-contained `vind` path:
  snapshots are rendered to the Forgejo OCI registry that is installed inside
  the local `vind` cluster

The self-contained `vind` path does this so you do not need to introduce S3
just to demonstrate snapshots locally.

The OCI image location therefore depends on how the repo was rendered:

- generator / GitHub:
  `oci://ghcr.io/{REPLACE_ORG_NAME}/{REPLACE_REPO_NAME}`
- self-contained `vind`:
  `oci://{REPLACE_OCI_REGISTRY_HOST}/{REPLACE_ORG_NAME}/{REPLACE_REPO_NAME}`

The corresponding credential secret also differs by render path:

- the original path keeps the GHCR-style secret naming
- the self-contained path renders the projected secret name used by the Forgejo
  registry bootstrap

## Self-Contained vind Notes

In the self-contained `vind` flow:

- `bootstrap-self-contained.sh` builds and pushes the demo image to the Forgejo
  container registry
- the same bootstrap creates the default Platform `ProjectSecret` used for
  registry auth
- the local-contained overlay points the auto-snapshots manifests at the
  self-contained version so Argo CD does not fight the populated registry
  secret

That keeps the `vind` path self-contained while leaving the original
demo-generator / GitHub path unchanged.

## Schedule

Snapshots are configured to run Monday through Friday at 15 minutes past the
hour from 7 AM through 5 PM.

The current snapshot config shape follows the vCluster Platform docs:

```yaml
external:
  platform:
    autoSnapshot:
      enabled: true
      schedule: "15 7-17/3 * * 1-5"
      timezone: America/New_York
      retention:
        period: 5
        maxSnapshots: 4
      storage:
        type: oci
        oci:
          repository: oci://{REPLACE_OCI_REGISTRY_HOST}/{REPLACE_ORG_NAME}/{REPLACE_REPO_NAME}
          credential:
            secretName: {REPLACE_ORG_NAME}-ghcr-write-pat
            secretNamespace: <vcluster-host-namespace>
```

This use case does not enable volume snapshots by default. The current docs
show that under:

```yaml
external:
  platform:
    autoSnapshot:
      volumes:
        enabled: true
```

but that requires the additional host or virtual cluster volume snapshot
prerequisites to already be in place.

## Restore

The vCluster CLI is still required to restore a given snapshot.

Example:

```bash
vcluster platform login https://{REPLACE_VCLUSTER_NAME}.{REPLACE_BASE_DOMAIN}
vcluster restore snappy oci://{REPLACE_OCI_REGISTRY_HOST}/{REPLACE_ORG_NAME}/{REPLACE_REPO_NAME}:snappy-20250826111511
```

## Demo Flow

1. Ensure that at least one snapshot has been created.
2. Confirm the OCI artifact exists in the rendered registry location.
3. Delete the `demo-web` `Deployment`.
4. Restore the snapshot with the vCluster CLI.
5. Return to the Platform UI and wait for the `snappy` vCluster instance to restart.
6. Confirm that the `demo-web` `Deployment` has been restored.

For the original GitHub-rendered path, the snapshot package is available in the
GitHub package UI here:

- `https://github.com/orgs/{REPLACE_ORG_NAME}/packages/container/package/{REPLACE_REPO_NAME}`

For the self-contained `vind` path, use the Forgejo package UI instead:

- `https://forgejo.vcp.local/{REPLACE_ORG_NAME}/-/packages/container/{REPLACE_REPO_NAME}`

> [!IMPORTANT]
> The self-contained `vind` path is wired to use the Forgejo OCI registry, but
> the registry-backed snapshot flow has not been validated as thoroughly yet as
> the Git hosting flow.

Official docs:

- [Platform snapshots](https://www.vcluster.com/docs/platform/use-platform/virtual-clusters/key-features/snapshots)
- [Snapshot and restore](https://www.vcluster.com/docs/vcluster/manage/backup-restore/)

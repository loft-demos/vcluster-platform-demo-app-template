# vCluster Automatic Snapshots

Snapshots are a built-in method to back up a vCluster as an OCI artifact that can be pushed to either:

- an OCI-compliant container registry
- an S3 bucket

This demo configures a `VirtualClusterTemplate` and example `VirtualClusterInstance` with snapshots configured under `snapshots.auto`.

## Registry Target By Deployment Mode

This use case now has two render paths:

- vCluster Platform Demo Generator / GitHub path: snapshots are pushed to GHCR
- self-contained `vind` path: snapshots also use GHCR for now

The OCI image location therefore depends on how the repo was rendered:

- generator / GitHub: `oci://ghcr.io/{REPLACE_ORG_NAME}/{REPLACE_REPO_NAME}`
- self-contained `vind`: `oci://ghcr.io/{REPLACE_ORG_NAME}/{REPLACE_REPO_NAME}`

The corresponding credential secret also differs by render path:

- the original path keeps the GHCR-style secret naming
- the self-contained path still uses the rendered projected secret name, but it should contain GHCR credentials instead of Forgejo credentials

## Self-Contained vind Notes

In the self-contained `vind` flow:

- `bootstrap-self-contained.sh` builds and pushes the demo image to the Forgejo container registry
- the same bootstrap can create the default Platform `ProjectSecret` used for snapshot registry auth when `GHCR_USERNAME` and `GHCR_TOKEN` or `GHCR_PASSWORD` are provided
- the local-contained overlay points the auto-snapshots manifests at the self-contained version so Argo CD does not fight the populated registry secret

The demo app image flow uses Forgejo. Snapshot storage stays on GHCR for the local `vind` path because the local Forgejo snapshot registry flow has not been validated for the in-cluster snapshot client yet.

## Schedule

Snapshots are configured to run Monday through Friday at 15 minutes past the hour from 7 AM through 5 PM.

The current snapshot config shape for `0.32+` is:

```yaml
snapshots:
  auto:
    schedule: "15 7-17/3 * * 1-5"
    timezone: America/New_York
    retention:
      period: 5
      maxSnapshots: 4
    storage:
      type: oci
      oci:
        repository: oci://{REPLACE_SNAPSHOT_OCI_REPOSITORY}
        credential:
          secretName: {REPLACE_ORG_NAME}-ghcr-write-pat
          secretNamespace: <vcluster-host-namespace>
```

This use case does not enable volume snapshots by default. If you need them, the config lives under:

```yaml
snapshots:
  volumes:
    enabled: true
```

but that requires the additional host or virtual cluster volume snapshot prerequisites to already be in place.

## Restore

The vCluster CLI is still required to restore a given snapshot.

Example:

```bash
vcluster platform login https://{REPLACE_VCLUSTER_NAME}.{REPLACE_BASE_DOMAIN}
vcluster restore snappy oci://{REPLACE_SNAPSHOT_OCI_REPOSITORY}:snappy-20250826111511
```

## Demo Flow

1. Ensure that at least one snapshot has been created.
2. Confirm the OCI artifact exists in the rendered registry location.
3. Delete the `demo-web` `Deployment`.
4. Restore the snapshot with the vCluster CLI.
5. Return to the Platform UI and wait for the `snappy` vCluster instance to restart.
6. Confirm that the `demo-web` `Deployment` has been restored.

For the original GitHub-rendered path, the snapshot package is available in the GitHub package UI here:

- `https://github.com/orgs/{REPLACE_ORG_NAME}/packages/container/package/{REPLACE_REPO_NAME}`

For the self-contained `vind` path, use the GitHub package UI instead:

- `https://github.com/orgs/{REPLACE_ORG_NAME}/packages/container/package/{REPLACE_REPO_NAME}`

> [!IMPORTANT]
> The self-contained `vind` path keeps snapshots on GHCR for now. A local
> Forgejo OCI registry endpoint is not a good default here yet because the
> in-cluster snapshot job path has not been validated end to end.

Official docs:

- [Platform snapshots](https://www.vcluster.com/docs/platform/use-platform/virtual-clusters/key-features/snapshots)
- [Snapshot and restore](https://www.vcluster.com/docs/vcluster/manage/backup-restore/)

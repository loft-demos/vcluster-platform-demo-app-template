# vCluster Automatic Snapshots

Snapshots are a built-in method to create backups of a vCluster as an OCI compliant image that may be pushed to an OCI compliant container registry or an S3 bucket.

This use case demo is configured to create a Virtual Cluster Template, and a Virtual Cluster Instance based on that template, with `autoSnapshots` enabled and configured to push the snapshot OCI images to a GitHub container registry (GHCR) on a cron based schedule. It also creates a `Secret`, from a vCluster Platform Project Secret, in the vCluster host namespace with a GitHub username and personal access token (password) that has `write` permissions to the configured GHCR.

Snapshots will be created and pushed to the respective GHCR Monday thru Friday at 15 minutes past the hour 7 AM until 5 PM.

Currently, the vCluster CLI is required to restore a given snapshot.

Demo Steps:

- Ensure that at least one snapshot has been created - it should be available at the following GHCR: https://github.com/orgs/{REPLACE_ORG_NAME}/packages/container/package/{REPLACE_REPO_NAME}
- Delete the `demo-web` `Deployment`
- Use the vCluster CLI to restore the snapshot (note that the tag will be different):

```
vcluster platform login https://{REPLACE_VCLUSTER_NAME}.{REPLACE_BASE_DOMAIN}
vcluster restore snappy oci://ghcr.io/{REPLACE_ORG_NAME}/{REPLACE_REPO_NAME}:snappy-20250826111511
```

- Return to the Platform UI, the snappy vCluster should be restarting
- Once the vCluster has restarted, show the the `demo-web` `Deployment` has been restored

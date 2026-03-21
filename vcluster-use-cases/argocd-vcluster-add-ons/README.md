# Argo CD vCluster Add-ons

This folder contains a small Argo CD `ApplicationSet` example that deploys
environment-specific add-on manifests to vCluster instances created through
vCluster Platform and imported into Argo CD with cluster labels.

The setup assumes the imported Argo CD cluster `Secret` for each vCluster has
an `env` label such as `dev`, `qa`, or `prod`. The `ApplicationSet` uses that
label to choose which manifest sub-folder to deploy for that cluster.

## Folder Layout

```text
vcluster-use-cases/argocd-vcluster-add-ons/
├── applicationsets/
│   └── vcluster-env-appset.yaml
└── manifests/
    ├── dev/
    │   └── env-config.yaml
    ├── qa/
    │   └── env-config.yaml
    └── prod/
        └── env-config.yaml
```

## What Each Folder Does

### `applicationsets/`

[`applicationsets/vcluster-env-appset.yaml`](./applicationsets/vcluster-env-appset.yaml)
defines an Argo CD `ApplicationSet` named `vcluster-env-config`.

It uses the Argo CD Cluster generator three times with selectors for:

- `env=dev`
- `env=qa`
- `env=prod`

For every matching imported cluster, it creates an Argo CD `Application` that:

- targets the matching cluster server
- deploys into the namespace `{REPLACE_REPO_NAME}-<env>`
- reads manifests from `vcluster-use-cases/argocd-vcluster-add-ons/manifests/<env>/`

The file includes the placeholders `{REPLACE_ORG_NAME}` and
`{REPLACE_REPO_NAME}`, which must be replaced with the GitHub organization and
repository that host the manifests.

### `manifests/dev/`

[`manifests/dev/env-config.yaml`](./manifests/dev/env-config.yaml) contains the
resources applied to clusters labeled `env=dev`.

Today this folder contains a single `ConfigMap` named `app-env-config` with:

```yaml
data:
  env: "dev"
```

### `manifests/qa/`

[`manifests/qa/env-config.yaml`](./manifests/qa/env-config.yaml) contains the
resources applied to clusters labeled `env=qa`.

Today this folder contains the same `app-env-config` `ConfigMap`, but with:

```yaml
data:
  env: "qa"
```

### `manifests/prod/`

[`manifests/prod/env-config.yaml`](./manifests/prod/env-config.yaml) contains
the resources applied to clusters labeled `env=prod`.

Today this folder contains the same `app-env-config` `ConfigMap`, but with:

```yaml
data:
  env: "prod"
```

## How It Is Used

This example is bootstrapped into Argo CD by the app-of-apps `Application`
defined in
[`vcluster-gitops/argocd/app-of-apps/argocd-vcluster-add-ons-app.yaml`](../../vcluster-gitops/argocd/app-of-apps/argocd-vcluster-add-ons-app.yaml).
That `Application` points Argo CD at the `applicationsets/` folder, which then
creates the environment-specific child `Application` resources for matching
vCluster instances.

## Notes

- This example depends on vCluster Platform importing vCluster instances into
  Argo CD as clusters with labels.
- The `env` label is the routing key that maps a cluster to the `dev`, `qa`,
  or `prod` sub-folder.
- The `project` field in the generated `Application` uses the imported cluster
  label `use-case.demos.vcluster.com/project`.
- You can extend the example by adding more manifests under each environment
  folder without changing the `ApplicationSet` structure.

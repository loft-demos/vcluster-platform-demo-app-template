# Rancher Integration

This folder contains the Rancher integration example for this repo.

The current setup installs:

- Rancher itself
- the `vcluster-rancher-operator`
- additional Rancher-side manifests from this repo

Folder layout:

```text
vcluster-use-cases/rancher-integration/
├── apps/
│   ├── rancher-helm-app.yaml
│   ├── rancher-manifests.yaml
│   └── vcluster-rancher-operator.yaml
└── manifests/
    └── rancher-project.yaml
```

What each app does:

- `apps/rancher-helm-app.yaml`
  installs Rancher from the upstream Rancher chart repo
- `apps/vcluster-rancher-operator.yaml`
  installs the vCluster Rancher operator from `charts.loft.sh`
- `apps/rancher-manifests.yaml`
  applies the repo-managed Rancher integration manifests

Current manifest:

- `manifests/rancher-project.yaml`
  is an example Rancher `Project` resource

This use case is intended for demos where Rancher and vCluster Platform are
shown together rather than as separate management stacks.

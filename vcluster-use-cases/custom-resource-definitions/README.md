# Custom Resource Definitions

This folder contains CRD-focused examples for demoing custom APIs inside a
vCluster or alongside Platform-managed resources.

Current example:

- `shirt-resource-definition/`
  - `v1/` defines a simple `Shirt` CRD and example resources
  - `v2/` evolves that CRD with additional schema fields and printer columns

This is a small, self-contained example for showing:

- CRD installation
- versioned CRD schema changes
- example custom resources that match each version

Folder layout:

```text
vcluster-use-cases/custom-resource-definitions/
└── shirt-resource-definition/
    ├── v1/
    │   ├── shirt-resource-definition.yaml
    │   └── shirt-resources.yaml
    └── v2/
        ├── shirt-resource-definition.yaml
        └── shirt-resources.yaml
```

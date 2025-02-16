# vCluster Platform Project Roles

vCluster Platform Project Roles are `ClusterRoleTemplate` resources (documented [here](https://www.vcluster.com/docs/platform/api/resources/clusterroletemplate)) with a special `metadata.label` of: `loft.sh/project-role: 'true'`

The example here updates the vCluster Platform OOTB **Project User** role with the `demos.loft.sh/aggregate-to-project-user: 'true'` label. This allows creating a new Project Role *loft-management-project-user-with-vcluster-logs* that aggregates the permissions from that role and just add the necessary permission to view vCluster logs.

The `aggregationRule`:
```
    aggregationRule:
      clusterRoleSelectors:
        - matchLabels:
            demos.loft.sh/aggregate-to-project-user: 'true'
```

Allows for minimal permission rules while retaining all of the existing **Project User** role rules:
```
    rules:
      - verbs:
          - get
          - list
        apiGroups:
          - management.loft.sh
        resources:
          - virtualclusterinstances/log
```

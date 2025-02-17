# vCluster Platform Project Roles

vCluster Platform **Project Role** are `ClusterRoleTemplate` resources (documented [here](https://www.vcluster.com/docs/platform/api/resources/clusterroletemplate)) with a special `metadata.label` of: `loft.sh/project-role: 'true'`

This example updates the vCluster Platform OOTB **Project User** role with the `demos.loft.sh/aggregate-to-project-user: 'true'` label. This allows creating a new Project Role *loft-management-project-user-with-vcluster-logs* that aggregates the permissions of that **Project Role** and adds the permission to view vCluster logs. This allows for basic troubleshooting of the vCluster's control plane logs without having additional access to the underlying host cluster.

The `aggregationRule` allows using an existing `ClusterRoleTemplate` as a base for the new role:
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

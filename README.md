# echo-app
Simple echo app and helm chart repository template to use with Loft Labs vCluster.Pro demo examples.

## vCluster.Pro Integration Examples

### Argo CD

vCluster.Pro includes an Argo CD integration that will automatically add a vCluster instance, created with a virtual cluster template, to Argo CD as a target cluster.

Here is an example `management.loft.sh/v1` `Project` manifest with unrelated configuration execluded (full version here):

```yaml
kind: Project
apiVersion: management.loft.sh/v1
metadata:
  name: api-framework
spec:
  displayName: API Framework
...
  argoCD:
    enabled: true
    cluster: loft-cluster
    namespace: argocd
    project:
      enabled: true
```

#### Example: ApplicationSet Pull Request Generator

#### Example: ApplicationSet Cluster Generator



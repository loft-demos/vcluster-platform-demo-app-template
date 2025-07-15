# Argo CD App of Apps for vCluster Platform

The [Argo CD App of Apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern) is used with the vCluster Platform Demo `VirtualClusterTemplate` to provide the installation of different vCluster Platform and vCluster use case based examples into the vCluster Platform Demo vCluster environment. Some of the use case examples are optional and others are enabled by default.  `VirtualClusterTemplate` [boolean parameters](https://www.vcluster.com/docs/platform/administer/templates/advanced/parameters) are used to dynamically set the values of the Argo CD Cluster `Secret` `metadata.labels` generated for the demo vCluster in the `argocd` `namespace` within the demo vCluster.

Once the demo vCluster is running and Argo CD is deployed into the demo vCluster (via a vCluster Platform `App` template), the vCluster Platform Demo *App of Apps* Argo CD `Application` is added to the demo vCluster Argo CD instance via the vCluster Platform GitOps seed `Application` (the seed `Application` is added with a vCluster Platform Bash `App`) via the [Kustomziation yaml configuration](../vcluster-gitops/kustomization.yaml).

The vCluster Platform Argo CD *App of Apps* triggers the creation of a number of additional Argo CD `ApplicationSets`, `Applications` and other Kubernetes manifests in the `app-of-apps` [folder](./app-of-apps) to include a number of Argo CD `ApplicationSets` that use the Cluster Generator to selectively create Argo CD `Applications` based on the value of the vCluster Platform Demo template generated Argo CD Cluster `Secret` `metadata.labels`. For example, the following Argo CD vCluster Demo Cluster `Secret` will trigger the `ApplicationSet` creation of the External Secrets Operator and Kyverno Argo CD `Applications`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  labels:
    # required for Argo CD to identify this as a target cluster
    argocd.argoproj.io/secret-type: cluster
    flux: 'true'
    resolveDNS: ''
    eso: 'true'
    kyverno: 'true'
    postgres: ''
    mysql: ''
    rancher: ''
  name: cluster-local
  namespace: argocd
stringData:
  config: '{"tlsClientConfig":{"insecure":false}}'
  name: in-cluster
  server: https://kubernetes.default.svc
type: Opaque
```

And here is an example Cluster Generator `ApplicationSet` configuration:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: eso-cluster
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            eso: 'true'
  template:
    metadata:
      name: 'eso-apps'
      labels:
        eso.demos.loft.sh: eso
    spec:
      destination:
        # server is the url of the cluster as selected by the spec above
        server: '{{server}}'
      ...
```

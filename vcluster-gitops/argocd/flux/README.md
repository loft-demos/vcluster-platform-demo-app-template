# Using Flux with vCluster Platform

By enabling the installation of Flux, the resulting vCluster Platform demo environment will include:

- [Flux2](https://fluxcd.io/flux/) - and, yes, we are using Argo CD to install Flux, please don't judge
- The [Capcitor UI](https://github.com/gimlet-io/capacitor)
- A Flux `GitRepository` for this reposiotry and mapped to the **Auth Core** vCluster Platform Project namespace - `p-auth-core`
- A Flux `Kustomization` resource that will create the `VirtualClusterInstance` resources defined under the [kustomize directory](./kustomize)

## Using the `VirtualClusterInstance` CRD
The `VirtualClusterInstance` CRD is documented [here](https://www.vcluster.com/docs/platform/api/resources/virtualclusterinstance/). It is a vCluster Platform custom Kubernetes resource for managing vCluster instances with vCluster Platform Projects.

The `VirtaulClusterInstance` `metadata.namespace` must be a valid vCluster Platform Project `namespace`. In the example [here](kustomize/vcluster-without-template.yaml#L5), the `metadata.namespace` matches to the **Auth Core** Project. But note, this is the `namespace` where the `VirtaulClusterInstance` will be created and not the `namespace` where the vCluster control plane will be deployed. 

The host cluster and `namespace` where the vCluster is deployed is configured under `spec.clusterRef` but you should only configure the `spec.cluterRef.cluster` as the `spec.clusterRef.namespace` and the `spec.clusterRef.name` will be automatically configured by vCluster Platform.

Additionally, instead of the `vcluster.yaml` values being a separate file, like in the case of creating a vCluster instance with Helm or with the vCluster CLI, the `vcluster.yaml` values are added as an object under the `spec.template.helmRelease.values` field - as in this [example](./kustomize/vcluster-without-template.yaml#L27-L44).



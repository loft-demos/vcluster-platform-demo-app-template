# Using Flux with vCluster Platform

By enabling the installation of Flux, the resulting vCluster Platform demo environment will include:

- [Flux2](https://fluxcd.io/flux/) - and, yes, we are using Argo CD to install Flux, please don't judge
- The [Capcitor UI](https://github.com/gimlet-io/capacitor)
- A Flux `GitRepository` for this reposiotry and mapped to the **Auth Core** vCluster Platform Project namespace - `p-auth-core`
- A Flux `Kustomization` resource that will create the `VirtualClusterInstance` resources defined under the [kustomize directory](./kustomize)

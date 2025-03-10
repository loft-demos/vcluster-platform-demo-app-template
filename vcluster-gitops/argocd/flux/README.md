# Using Flux with vCluster Platform

By enabling the installation of Flux, the resulting vCluster Platform demo environment will include:
- apps:
  - Flux Operator - includes Flux `ResourceSets` use for provisioning ephemeral vCluster Pull Request environments 
  - [Flux2](https://fluxcd.io/flux/) 
- manifests:
  - The [Capcitor UI](https://github.com/gimlet-io/capacitor), a UI for Flux
  - A vCluster Platform `VirtualClusterTemplate` resource to be used to create one of the `VirtualClusterInstances` below
  - A vCluster Platform Bash `App` that can be used with `VirtualClusterInstances` to create a Flux KubeConfig `Secret` in a vCluster Platform host or connected cluster when running a single instance of Flux
  - A Flux `GitRepository` for this reposiotry and mapped to the **Auth Core** vCluster Platform Project namespace - `p-auth-core`
  - A Flux `Kustomization` resource that will create the `VirtualClusterInstance` resources defined under the [kustomize directory](./kustomize)
- pull-request-environments: Example of dynamic provisioning of vCluster instances for ephemeral Pull Request environments with Flux `ResourceSets`
  - A Flux Operator `ResourceSetInputProvider` configured for GitHub Pull Requests
  - A Flux Operator `ResourceSet` that includes:
    - A `Kustomization` Flux resource to provision a Pull Request specific `VirtualClusterInstance` with a custom `healthCheckExprs` so the vCluster is not considered healtyh and ready by Flux until it is fully up and running
    - A `Kustomization` Flux resource to wrap a `HelmRelease` to provide a dependsOn` for the PR `VirtualClusterInstance` so Flux will not attempt to deploy the Helm app until the vCluster is ready

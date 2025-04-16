# Using Flux with vCluster Platform

By enabling the Flux demo setup, the resulting vCluster Platform demo environment will include:
### Applications (apps): 
Argo CD `Application` resources that will trigger additional installs
  - [Flux Operator](https://fluxcd.control-plane.io/operator/) - Managed the Flux2 install as a `FluxInstance` and provides Flux `ResourceSets` to provision ephemeral vCluster environments for pull requests.
  - Flux related manifests to include a `FluxInstance` managed by the Flux Operator
  - Flux Pull Request Environments Manifests
### Manifests:
  - [Flux2](https://fluxcd.io/flux/) - The core Flux GitOps engine, installed with the Flux Operator managed [`FluxInstance`](./manifests/flux-instance.yaml)
  - Headlamp with the Flux plugin - A user interface for visualizing and managing some aspects of Flux.
  - vCluster Platform `VirtualClusterTemplate` - A vCluster Platform resource used to create `VirtualClusterInstances` with the required configuration to integrated easily with Flux.
  - vCluster Platform Bash `App` - Enables automatic creation of a Flux KubeConfig Secret for `VirtualClusterInstances` in a vCluster Platform host or connected cluster when running a single instance of Flux for `VirtualClusterInstances` deployed across multiple vCluster Platform host clusters.
  - Flux `GitRepository` - Points to this repository and is mapped to the p-auth-core namespace in the Auth Core vCluster Platform Project.
  - A Flux `Kustomization` resource that will create the `VirtualClusterInstance` resources defined under the [kustomize directory](./kustomize)
### Pull Request Environments: 
Example of dynamic provisioning of vCluster instances for ephemeral Pull Request environments with Flux `ResourceSets`
  - A Flux Operator `ResourceSetInputProvider` configured for GitHub Pull Requests
  - A Flux Operator `ResourceSet` that includes:
    - A `Kustomization` Flux resource to provision a Pull Request specific `VirtualClusterInstance` with a custom `healthCheckExprs` so the vCluster is not considered healtyh and ready by Flux until it is fully up and running
    - A `Kustomization` Flux resource to wrap a `HelmRelease` to provide a dependsOn` for the PR `VirtualClusterInstance` so Flux will not attempt to deploy the Helm app until the vCluster is ready

# Using Flux with vCluster Platform

By enabling the Flux demo setup, the resulting vCluster Platform demo environment will include:

## Applications (apps)

Argo CD `Application` resources that will trigger additional installs:

- [Flux Operator](https://fluxcd.control-plane.io/operator/) - Managed the Flux2 install as a `FluxInstance` and provides Flux `ResourceSets` to provision ephemeral vCluster environments for pull requests.
- Flux related manifests to include a `FluxInstance` managed by the Flux Operator
- Flux Pull Request Environments Manifests

## Manifests

- [Flux2](https://fluxcd.io/flux/) - The core Flux GitOps engine, installed with the Flux Operator managed [`FluxInstance`](./manifests/flux-instance.yaml)
- Headlamp with the Flux plugin - A user interface for visualizing and managing some aspects of Flux.
- vCluster Platform `VirtualClusterTemplate` - A vCluster Platform resource used to create `VirtualClusterInstances` with the required configuration to integrate easily with Flux via a custom generated `kubeconfig` secret.
- vCluster Platform Bash `App` - Enables automatic creation of a Flux KubeConfig Secret for `VirtualClusterInstances` in a vCluster Platform host or connected cluster when running a single instance of Flux for `VirtualClusterInstances` deployed across multiple vCluster Platform host clusters.
- Flux `GitRepository` - Points to this repository and is mapped to the `p-vcluster-flux-demo` namespace in the _vCluster Flux Demo_ vCluster Platform Project.
- A Flux `Kustomization` resource that will create the `VirtualClusterInstance` resource defined under the [kustomize directory](./kustomize)

## Pull Request Environments

Example of dynamic provisioning of vCluster instances for ephemeral Pull Request environments with Flux `ResourceSets`

- A Flux Kustomization that creates the necessary secrets for the Flux vCluster PR use case example
- A Flux Operator `ResourceSetInputProvider` configured for GitHub Pull Requests and with `defaultValues` that include a list of Kubernetes versions.
- A Flux Operator `ResourceSet` that includes the following resources for each Kubernetes version listed in the `ResourceSetInputProvider` `defaultValues`:
  - A `Kustomization` Flux resource to provision a Pull Request specific `VirtualClusterInstance`. It also includes a custom `healthCheckExprs` so the vCluster is not considered healthy and ready by Flux until it is up and running.
  - A `Kustomization` Flux resource to wrap a `HelmRelease` to provide a dependsOn` for the PR `VirtualClusterInstance` so Flux will not attempt to deploy the Helm app until the vCluster is ready
  - Two Flux `GitRepository` resources. One associated with the `VirtualClusterInstance` `Kustomization` and scoped to the PR head branch so new PR commits won't trigger updates. And the other associated with the PR `HelmRelease` deployed into the vCluster and scoped to PR head branch commits, so every commit will result in an udpated app deployment in the matching vCluster.
  - A Flux generic notifications `Provider` and `Alert` that is triggered whenever there is a new commit push the PR head branch and will trigger the wake-up from sleep mode for any sleeping PR vCluster instances. This allows utilizing vCluster sleep mode while still ensuring that all new commits are promptly updated and available.

NOTE: For using the bash App script to create a Flux vCluster kubeconfig:

- To create the `kubeconfig` secret in another cluster you can use the vcluster CLI to connect to that cluster and set the appropriate namespace for the generated `kubeconfig` secret
- For example, using `-n p-{{ .Values.loft.project }}` will create the secret in the Platform Project of the vCluster instance
- Then use the CLI to connect to vCluster Platform: vcluster platform login https://tango.us.demo.dev --access-key $ACCESS_KEY
- Then connect to the Platform host cluster where Flux will retrieve the `kubeconfig` secret: vcluster platform connect cluster loft-cluster
- You will also need to ensure that all Flux resources that require that vCluster `kubeconfig` are also deployed to that same namespace

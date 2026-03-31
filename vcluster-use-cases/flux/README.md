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
- A Flux-managed host-cluster Kargo path under [host-apps/kargo](./host-apps/kargo) that is enabled by the continuous-promotion use case when `flux=true`

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

## Optional: Flux-manage Kargo

If you want Flux to install Kargo instead of Argo CD:

1. Enable the continuous-promotion and flux use cases together so Argo CD creates the Flux `Kustomization` from [../continuous-promotion/manifests-flux-kargo/flux-kargo-host-apps.yaml](../continuous-promotion/manifests-flux-kargo/flux-kargo-host-apps.yaml).
2. Put the host-side Kargo resources under [host-apps/kargo](./host-apps/kargo).
3. Create the `kargo-auth-values` Secret or `ExternalSecret` in namespace `p-vcluster-flux-demo`.
4. The continuous-promotion Flux bridge now creates its own `GitRepository` (`vcluster-flux-demo-kargo`) so the Kargo host-app path does not race the separate `flux-manifests` source bootstrap.
5. Flux will wait for the ESO-backed Kargo auth secret, install the Kargo chart, wait for the cluster webhook secret, then reconcile the `pre-prod-gate` and `progressive-delivery` Kargo manifests by using Flux `dependsOn`.
6. The legacy Argo CD-managed Kargo path is now opt-in through the `legacyArgoKargo=true` cluster label. On the `vind` self-contained path, bootstrap derives that label automatically whenever `continuous-promotion` is enabled without `flux`.

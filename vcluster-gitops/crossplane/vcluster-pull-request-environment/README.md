# Ephemeral vCluster for Pull Requests
### with Ephemeral Argo CD Instance 

This setup enables the automatic creation of ephemeral vCluster instances for each pull request, complete with an ephemeral Argo CD deployment inside that vCluster for managing application code changes dynamically.

## Key Components & Workflow
1. vCluster Platform
   - Utilizes `VirtualClusterInstance` and `VirtualClusterTemplate` vCluster Platform CRDs as part of the `pullrequestenvironments` Crossplane composition to dynamically provision vCluster instances.
   - The `App` CRD deploys Argo CD inside each ephemeral vCluster, configuring an ApplicationSet for managing GitHub-based applications.
   - Supports SSO via OIDC for secure authentication.
2. Crossplane
   - Manages cloud-native resources using [Kubernetes](https://github.com/loft-demos/loft-demo-base/tree/main/vcluster-platform-demo-generator/crossplane/provider-kubernetes) and [GitHub](https://github.com/loft-demos/loft-demo-base/tree/main/vcluster-platform-demo-generator/crossplane/provider-github) providers.
   - Uses compositions resources definitions to automate provisioning of ephemeral PR vCluster:
     - `XPullRequestEnvironment`: Creates an isolated vCluster environment for each pull request.
     - `XArgoCDWebhook`: Manages ephemeral webhooks for triggering Argo CD deployments for every commit to a Pull Request head branch.
3. Argo CD
   - Deploys an ApplicationSet leveraging the Pull Request Generator, ensuring each PR gets its own isolated environment for testing.
4. Ingress Nginx
   - Provides ingress routing for ephemeral vClusters and Argo CD instances.

## How It Works
- When a pull request is opened, Argo CD triggers Crossplane to provision an ephemeral vCluster using a VirtualClusterTemplate - see [pull-request-vcluster.yaml](../../virtual-cluster-templates/pull-request-vcluster.yaml).
- Another, completely ephemeral, Argo CD instance is deployed inside the vCluster, and an ApplicationSet is created to manage the application from the PR branch.
- The system integrates OIDC-based SSO, allowing developers to access Argo CD securely.
- Upon merging or closing the PR, the ephemeral environment is automatically cleaned up, keeping the system efficient and cost-effective.

This approach enables fast, isolated, and repeatable CI/CD workflows, enhancing development velocity and reducing integration risks.

## Component List

- vCluster Platform
  - `VirtualClusterInstance` CRD
  - `VirtualClusterTemplate` CRD
  - `App` CRD - Used to install Argo CD into the ephemeral vCluster instance and the Argo CD `ApplicationSet` for the GitHub repo application code
    - Argo CD `App`
    - Argo CD ApplicationSet `App`
  - SSO via OIDC
- Crossplane
  - Providers:
    - Kubernetes Provider
    - GitHub Provider
  - Compositions (with XRD and XRC/XR)
    - `XPullRequestEnvironment`
    - `XArgoCDWebhook`
- Argo CD
  - ApplicationSet using the Pull Request Generator 
- Ingress Nginx
- vCluster - created with a `VirtualClusterTemplate`
  - Argo CD
    - ApplicationSet using the Pull Request Generator

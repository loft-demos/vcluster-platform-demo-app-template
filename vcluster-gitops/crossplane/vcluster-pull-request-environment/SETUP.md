# Setup for Ephemeral vCluster for Pull Requests

To set up ephemeral vCluster instances for pull requests, each containing an ephemeral Argo CD deployment to manage application code changes, follow these steps:

**1. Install vCluster Platform:**
  - Ensure that vCluster Platform is installed in your Kubernetes environment.
  - Refer to the vCluster Platform documentation for [installation instructions](https://www.vcluster.com/docs/platform/install/quick-start-guide).

**2. Create an `App` custom resource for Argo CD in vCluster Platform** - see [vcluster-gitops/apps/argo-cd.yaml](../../apps/argo-cd.yaml):
  
  `kubectl apply -f argo-cd.yaml -n vclusterr-platform`
  
  - Install Argo CD into the same cluster where vCluster Platform is installed with the `App`: [Installing Apps on a Cluster](https://www.vcluster.com/docs/platform/use-platform/apps/use-on-demand#installing-apps-on-a-cluster)

**3. Create an `App` custom resource for the ApplicationSet** - to be deployed to the ephemeral Argo CD to manage the deployment of your application's code from the repository - see [vcluster-gitops/apps/argo-cd-pr-application-set.yaml](../../apps/argo-cd-pr-application-set.yaml):
  
  `kubectl apply -f argo-cd-pr-application-set.yaml -n vcluster-platform`

**4. Configure the VirtualClusterTemplate:**
  - Define a `VirtualClusterTemplate` custom resource that specifies the configuration for the ephemeral vCluster instances.
  - Configure the values for Argo CD within the ephemeral vCluster: 
    - Configure SSO via OIDC:
      - Set up Single Sign-On (SSO) using OpenID Connect (OIDC) within the vCluster Platform for secure authentication to the ephemeral vClusters and Argo CD instances.

**5. Set Up Crossplane Composition:**
  - Utilize Crossplane to create a composition that includes the VirtualClusterInstance and other necessary resources.
  - The composition should be configured to handle the provisioning of resources upon the creation of a pull request with the `pr-vcluster` label.

**6. Create and Label a Pull Request:**
  - When creating a pull request that requires an ephemeral environment, add the pr-vcluster label to trigger the provisioning process.


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
  - Define a `VirtualClusterTemplate` custom resource that specifies the configuration for the ephemeral vCluster instances - see [vcluster-gitops/virtual-cluster-templates/pull-request-vcluster.yaml](../../virtual-cluster-templates/pull-request-vcluster.yaml)
  - Within that template:
    - Configure the values for the Argo CD `App` - see [vcluster-gitops/virtual-cluster-templates/pull-request-vcluster.yaml#L42-L93](../../virtual-cluster-templates/pull-request-vcluster.yaml#L42-L93)
    - Configure SSO via OIDC:
      - Set up Single Sign-On (SSO) using OpenID Connect (OIDC) within the vCluster Platform for secure authentication to the ephemeral vClusters and Argo CD instances.

**5. Creater a vCluster Platform Project:** This example uses the **API Framework** Project - see [vcluster-gitops/projects/projects.yaml#L1-L68](../../projects/projects.yaml#L1-L68)

    `kubectl apply -f projects.yaml -n vcluster-platform`

**6. Install Crossplane into the same cluster where vCluster Platform is installed:**

```
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm update --install crossplane --namespace crossplane-system --create-namespace crossplane-stable/crossplane --version 1.17.4
```

**7. Set Up Crossplane Composition:**
  - Utilize Crossplane to create a composition that includes the VirtualClusterInstance and other necessary resources.
  - The composition should be configured to handle the provisioning of resources upon the creation of a pull request with the `pr-vcluster` label.

**8. Create and Label a Pull Request:**
  - When creating a pull request that requires an ephemeral environment, add the pr-vcluster label to trigger the provisioning process.


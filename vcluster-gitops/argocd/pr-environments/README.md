# Ephemeral Preview Environments for Pull Requests 

**with vCluster and Argo CD**

This example leverages the vCluster Platform Argo CD integration that automatically adds a vCluster instance to an Argo CD instance that has been added to a vCluster Platform Project by creating an Argo CD Cluster `Secret`. This integration includes the syncing of the `VirtualClusterInstance` CRD `metadata.labels` to the Argo CD Cluster `Secret`. These `labels` can then be used with the Argo CD Application Set Cluster Generator.

On the Argo CD side, this examples leverages two different Argo CD Application Sets. The first Application Set is responsible for creating the vCluster for the Pull Request. The second Application Set is responsible for deploying the example application to that vCluster.

> [!NOTE]
> The Application Set that is responsible for creating the vCluster does not have to be in a vCluster Platform Project integrated Argo CD instance, but it does have to have the ability to create Kubernetes resources in the Kubernetes cluster where the vCluster Platform is installed - more specifically, it must be able to apply the `VirtualClusterInstance` resources to a vCluster Platform Project `Namespace`.
> The second Application Set must be applied to the same Argo CD instance that is integrated with the vCluster Platform Project where the Pull Request vCluster is created, as that vCluster must be available as the target server for the example application deployment.

### Components:
- vCluster Platform: leverages the `VirtualClusterInstance` CRD
- vCluster instances
- Argo CD
  
#### Argo CD ApplicationSets:
- **Pull Request Generator based ApplicationSet** creates the vCluster instances via a Kustomize app that is automatically added as a server to an Argo CD instances that is intergrated with a vCluster Platform Project
  - A Pull Request label, `create-pr-vcluster-external-argocd` is used to filter Pull Requests and make the ephermeral preview environment opt in, instead of created for every repostiory pull request. This is optional.
  - **Kustomize App:** A Kustomize app is used to create the `VirtualClusterInstance` so that the *Pull Request Generator based ApplicationSet* may add dynamic labels that will then be applied to the Argo CD cluster `Secret` via the vCluster Platform integration, and eventually utilized by the *Cluster Generator based ApplicationSet*. These labels include:
    - `vclusterName`: Used to create a reference to this `VirtualClusterInstance` as the `server` URL value
    - `repo`: the repository for the GitHub Pull Request and the application code that needs to be deployed by Argo CD
    - `pr`: Set to 'true' and used as a filter for the *Cluster Generator based ApplicationSet* so that only Pull Request ephemeral vCluster instances will trigger the generate of an Argo CD `Application` to deploy the Pull Request association application
    - `targetRevision`: The commit SHA of the Pull Request head branch to target for the generated Argo CD `Application`
- **Cluster Generator based ApplicationSet** uses labels, dynamically added to the `VirtualClusterInstance` created with the Pull Request Generator based ApplicationSet, to deploy the actual application code associated with the head commit of the Pull Request (in this example it is a Helm based application)


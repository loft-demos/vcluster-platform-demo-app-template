# Ephemeral Preview Environments for Pull Requests 

**with vCluster and Argo CD**

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


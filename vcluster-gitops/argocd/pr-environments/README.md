# Ephemeral Preview Environments for Pull Requests with vCluster and Argo CD

vCluster Platform
vCluster instance
Argo CD ApplicationSets:
- Pull Request Generator based ApplicationSet creates the vCluster instances via a Kustomize app that is automatically added as a server to an Argo CD instances that is intergrated with a vCluster Platform Project
- Cluster Generator based ApplicationSet uses labels, dynamically added to the `VirtualClusterInstance` created with the Pull Request Generator based ApplicationSet, to deploy the actual application code associated with the head commit of the Pull Request (in this example it is a Helm based application)


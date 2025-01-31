# Ephemeral vCluster with Ephemeral Argo CD Instance for Pull Requests

## Ingredients

- vCluster Platform
- Crossplane
- Argo CD
  - ApplicationSet using the Pull Request Generator 
- Ingress Nginx
- vCluster - created with a `VirtualClusterTemplate`
  - Argo CD
    - ApplicationSet using the Pull Request Generator

# Ephemeral vCluster for Pull Requests
with Ephemeral Argo CD Instance 

## Ingredients

- vCluster Platform
  - `VirtualClusterInstance` CRD
  - `VirtualClusterTemplate` CRD
  - SSO via OIDC
- Crossplane
- Argo CD
  - ApplicationSet using the Pull Request Generator 
- Ingress Nginx
- vCluster - created with a `VirtualClusterTemplate`
  - Argo CD
    - ApplicationSet using the Pull Request Generator

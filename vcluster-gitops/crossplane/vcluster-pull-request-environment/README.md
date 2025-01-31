# Ephemeral vCluster for Pull Requests
### with Ephemeral Argo CD Instance 

## Ingredients

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

# External Secrets Operator Integration for vCluster Pro

By enabling the installation of ESO, the resulting vCluster Platform demo environment will include:

- The External Secrets Operator (ESO) is installed by an Argo CD Helm `Application`
- An ESO `ClusterStore` using the Kubernetes provider is created along with a dummy demo `Secret`
- A vCluster Platform `VirtualClusterTemplate` is created with a `vcluster.yaml` configured with the ESO integration 

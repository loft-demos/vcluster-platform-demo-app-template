# MySQL Operator 
## with the vCluster Platform Database Connector Feature

The MySQL Operator simplifies deploying and managing MySQL clusters on Kubernetes by automating provisioning, scaling, backups, and failover while ensuring high availability and secure access. The [vCluster Platform Database Connector](https://www.vcluster.com/docs/platform/administer/connector/database) allows admins to configure a shared database server to manage backing stores for multiple virtual clusters, automatically creating isolated databases and non-privileged users per vCluster. This integration streamlines database management, enhances security, and enables seamless scaling of virtual clusters with external database support.

By enabling the installation of MySQL, the resulting vCluster Platform Demo environment will include:
- the installation of the MySQL operator by an Argo CD Helm `Application`
- the creation of an InnoDB MySQL Cluster utilizing a credentials `Secret` created from a vCluster Platfrom Demo `ProjectSecret` [here](https://github.com/loft-demos/loft-demo-base/blob/main/vcluster-platform-demo-generator/vcluster-platform-gitops/project-secrets/project-secrets.yaml#L68-L77)
- the creation of a vCluster Platform database connector `Secret` created from a vCluster Platfrom Demo `ProjectSecret` [here](https://github.com/loft-demos/loft-demo-base/blob/main/vcluster-platform-demo-generator/vcluster-platform-gitops/project-secrets/project-secrets.yaml#L79-L88)
- the creation of the *Database Connector Virtual Cluster* `VirtualClusterTemplate` [configured](./manifests/db-connected-vcluster-template.yaml#L69-L73) to use the vCluster Platform Demo database connector for its `backingStore`
- the creation of a `VirtualClusterInstance` [configured](./manifests/database-connector-vcluster.yaml#L15-L17) to use the *Database Connector Virtual Cluster* `VirtualClusterTemplate`


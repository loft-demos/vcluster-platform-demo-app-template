# Resolve DNS Example

Resolve DNS is a vCluster Pro distro feature and this example is based on the vCluster documentation [here](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/networking/resolve-dns). Resolve DNS is a core feature of the vCluster Pro CoreDNS plugin that is part of the [embedded CoreDNS](https://www.vcluster.com/docs/vcluster/next/configure/vcluster-yaml/control-plane/components/coredns#integrated-coredns) available with the vCluster Pro distribution.

This example includes two vCluster instances deployed to two different vCluster Platform projects. 

The **vcluster-a** vCluster in the Alpha project includes an Nginx `Deployment` and `Service` named `nginx-a` in the `svc-a` `Namespace`.

The **vcluster-b** vCluster in the Beta project includes the following `resolveDNS` configuration and deploys a `Pod` with `curl` to demonstrate the working Resolve DNS configuration:
```
networking:
  resolveDNS:
    - service: svc-b/nginx-b
      target:
        vClusterService: alpha-v-vcluster-a/vcluster-a/svc-a/nginx-a
controlPlane:
  coredns:
    enabled: true
    embedded: true
```
The vCluster Pro embedded CoreDNS with the resolve DNS plugin must be used, as show in the example configuration, by setting `embedded: true`. The `resolveDNS` configuration maps the Nginx `Service` deployed to **vcluster-a** to a DNS entry in **vcluster-b** that resolves to `nginx-b.svc-b.svc.cluster.local`.

## Manual Setup

1. Login to the vCluster Platform:
    ```
    vcluster platform login https://your.vcluster-platform.host
    ```
2. Create a kube context to the vCluster platform Management API:
    ```
    vcluster platform connect management
    ```
3. Clone this repository:
    ```
    git clone https://github.com/loft-demos/vcluster-platform-demo-app-template.git
    ```
4. Change into the `vcluster-platform-demo-app-template/vcluster-gitops/argocd/resolve-dns/` directory:
    ```
    cd vcluster-platform-demo-app-template/vcluster-gitops/argocd/resolve-dns/
    ```
5. Deploy the [projects.yaml](./manifests/projects.yaml) manifest:
    ```
    kubectl apply -f ./manifests/projects.yaml
    ```
6. Deploy the [vcluster-a.yaml](./manifests/vcluster-a.yaml) manifest:
    ```
    kubectl apply -f ./manifests/vcluster-a.yaml
    ```
7. Deploy the [vcluster-b.yaml](./manifests/vcluster-b.yaml) manifest:
    ```
    kubectl apply -f ./manifests/vcluster-b.yaml
    ```

## vCluster Platform Demo Setup
1. When creating a new vCluster Platform demo vCluster select **Resolve DNS** under the **Feature Examples** section. That will result in the above manifest automatically being deployed to the vCluster Platform demo environment vCluster.

## Demonstrate the Resolve DNS Feature
After you have setup your environment, either manually or via the automate Demo generator, you an demonstrate the Resolve DNS feature with the following steps:
1. Connect to **vcluster-b**:
    ```
    vcluster platform connect vcluster vcluster-b --project beta
    ```
2. Launch an interactive shell inside the `curl-pod` running inside of `vcluster-b`:
    ```
    kubectl exec -it curl-pod -n default -- /bin/ash
    ```
3. Within the interactive shell of the `curl-pod` executive the following `curl` command:
    ```
    curl nginx-b.svc-b.svc.cluster.local
    ```
4. The response will be the HTML of the default nginx welcome page.



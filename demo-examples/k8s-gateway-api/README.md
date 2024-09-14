This example depends on installing the manifests in `/vcluster-gitops/examples/k8s-gateway-api-with-istio.yaml` into a vCluster Platform host/connected cluster.

Once those Apps and the Virtual Cluster Template are installed, you need to deploy the `gateway.yaml` in this folder to the same host cluster.

Next, create vCluster instances from the `Kubernetes Gateway API Example` Virtual Cluster Template. Once that vCluster is up an running you will be able to create an `HTTPRoute` resource in that vCluster using the `httpbin-httproute.yaml` file in this directory.

Once the `HTTPRoute` has synced to the host cluster you will be able to test it with the following commands in the kube context of the host cluster:

```
export INGRESS_HOST=$(kubectl get gateways.gateway.networking.k8s.io gateway -n istio-ingress -ojsonpath='{.status.addresses[0].value}')
curl -s -I -HHost:httpbin.example.com "http://$INGRESS_HOST/get"
```

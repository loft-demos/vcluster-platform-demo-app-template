This example depends on installing the /vcluster-gitops/apps/k8s-gateway-api-istio.yaml Apps and the /vcluster-gitops/virtual-cluster-templates/k8s-gateway-api-example.yaml into a vCluster Platform host/connected cluster.

Once those Apps are installed (to include the Kubernetes Gateway API CRDs), you need to deploy the `gateway.yaml` to the same host cluster.

Next, create vCluster instances from the `k8s-gateway-api-example` Virtual Cluster Template. Once that vCluster is up an running you will be able to create an `HTTPRoute` resource in that vCluster using the `httpbin-httproute.yaml` file in this directory.

Once the `HTTPRoute` has synced to the host cluster you should be able to test it with the following commands in the kube context of the host cluster:

```
export INGRESS_HOST=$(kubectl get gateways.gateway.networking.k8s.io gateway -n istio-ingress -ojsonpath='{.status.addresses[0].value}')
curl -s -I -HHost:httpbin.example.com "http://$INGRESS_HOST/get"
```

# vNode with vCluster

[vNode](https://www.vnode.com/docs) enhances the tenant separation already provided by vCluster by providing strong node-level isolation through Linux user namespaces and seccomp filters for vCluster workloads. The use case examples installed will highlight the integration of vNode with vCluster and can be used to demonstrate the hard multi-tenant isolation provided by vNode for vCluster workloads.

Enabling this use case for the demo environment will create:

- The *vnode-demo-template* `VirtualClusterTemplate` that deploys the `vnode` `RuntimeClass` into the vCluster along with two highly privileged `Deployments` deployed to the same `node`, one using the `vnode` `RuntimeClass` and the other not using it. This allows you to easily **breakout** of the non-vnode workload and have root access to the underlying node, whereas the same is not possible with the **vnode enabled** workload.
- Deploy a vCluster instances using the *vnode-demo-template* in the Default project
- The *vcluster-pss-baseline-vnode-config* `VirtualClusterTemplate` that provides a configuration with Pod Security Standards configured for the vCluster control plane Kubernetes API server Pod Security Admission Controller. The configuration is passed to the vCluster Kubernetes kube-apiserver via the *pod-security-admission-config* `ConfigMap` configured as part of the template. The passed in Kubernetes API Server `AdmissionConfiguration`, for the `PodSecurity` plugin `PodSecurityConfiguration`, enforces the **Baseline Pod Security Standards** policy with an exception for vCluster workloads using the `vnode` `runtimeClass`.
- The *vnode-runtime-class-sync-with-vnode-launcher* `VirtualClusterTemplate` deploys the `vnode` `RuntimeClass` into the vCluster created with this template. Additionally, this templates creates a `vnode-launcher` `pod` in the host namespace of the vCluster that will allow sharing a single vNode runtime across multiple vCluster workload pods.

## Privilege Escalation vNode Demo

This demo shows how easy it is to breakout of a privileged container while also showing that the same type of breakout is not possible with vNode.

### Prerequisites

A Kubernetes cluster with [vNode installed](https://www.vnode.com/docs/#before-you-begin) that is connected to your vCluster Platform demo environment - the vCluster Demo Generator cluster has vNode installed in the root GKE host cluster.

If you aren't using the vCluster Demo Generator cluster and don't have a Kubernetes cluster with vNode installed already available, it is probably easiest to use a KinD cluster - [KinD Quickstart](https://kind.sigs.k8s.io/docs/user/quick-start/).

Once you have a KinD cluster up and running, [connect it to your vCluster Platform](https://www.vcluster.com/docs/platform/administer/clusters/connect-cluster?x0=3) demo environment.

[Install vNode](https://www.vnode.com/docs/#install-vnode).

In vCluster Platform create a vCluster in the Default project from the vNode Demo Template. This will create the `vnode` `RuntimeClass` in the vCluster and create two highly privileged `Deployments` - one using the vNode `RuntimeClass` and the other not use it.

### Show that the breakout test container without vNode is able to see the node's full process tree

- shell in the  `breakout-test` (non-vnode) `pod` (recommend using K9s if you have it installed)
- run `whoami` and run `pstree -p` to show the full `node` process tree
- get the process id of the vnode `pod` lowest level `vnode-container` - it would be **3096** in the example below

 ```bash
 whoami
pstree -p
...
|-vnode-container(2975)-+-vnode-init(3001)-+-vnode-container(3096)-+-pause(3120)
           |                       |                       |                  |-sh(3537)
```

### Show that the vNode looks privileged but is only able to see the vNode process tree

- shell into the `breakout-test-vnode` `pod` that is configured with the `vnode` `runtimeClass`
- run `whoami` and run `pstree -p` to show the reduced process tree
- change directory to what seems like the node's real root directory - `/proc/1/root`
- create the file `i-think-i-am-root` and show that the file is owned by `root` within the vNode

```
whoami
pstree -p
cd /proc/1/root 
touch i-think-i-am-root
ls -ltr
```

### On the physical node switch to root and create a file

If you are using KinD, you can access the KinD cluster node via Docker with `docker exec -it $(docker ps -aqf "name=kind-control-plane") bash` on the machine where you are running KinD (as long as you created a single node KinD cluster).

```bash
sudo -i #not necessary for KinD
cd /
touch i-am-the-real-root-do-not-delete
ls -ltr
```

### Switch back to the breakout test container without vNode

- change directory into the root of that process of the vNode `pod` container
- list the files and point out that the `i-think-i-am-root` is not owned by `root` outside of the vNode
- show that you are able to delete the `i-think-i-am-root` created in the vNode `pod` container
- next change into the actual root of the node using `/proc/1/root`

```bash
cd /proc/3096/root
ls -ltr
rm i-think-i-am-root
ls -ltr

cd /proc/1/root
ls -ltr
rm i-am-the-real-root-do-not-delete
ls -ltr
```

### Back on the physical node as root, show that the file was delete

```bash
ls -ltr
```

## Compare Performance

TODO

```
crictl stats

```
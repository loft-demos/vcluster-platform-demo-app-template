# vNode with vCluster

vNode enhances the tenant separation already provided by vCluster by providing strong node-level isolation through Linux user namespaces and seccomp filters for vCluster workloads. The use case examples installed will highlight the integration of vNode with vCluster and can be used to demonstrate the hard-mulitenant isolated provided by vNode for vCluster workloads.

Enabling this use case for the demo environment will create:

- The *vnode-demo-template* `VirtualClusterTemplate` that deploys the `vnode` `RuntimeClass` into the vCluster along with two highly privileged `Deployments` deployed to the same `node`, one using the `vnode` `RuntimeClass` and the other not using it. This allows you to easily **breakout** of the non-vnode workload and have root access to the underlying node, whereas the same is not possible with the **vnode enabled** workload.
- The *vcluster-pss-baseline-vnode-config* `VirtualClusterTemplate` that provides a configuration with Pod Security Standards configured for the vCluster control plane Kubernetes API server Pod Security Admission Controller. The configuration is passed to the vCluster Kubernetes kube-apiserver via the *pod-security-admission-config* `ConfigMap` configured as part of the template. The passed in Kubernetes API Server `AdmissionConfiguration`, for the `PodSecurity` plugin `PodSecurityConfiguration`, enforces the **Baseline Pod Security Standards** policy with an exception for vCluster workloads using the `vnode` `runtimeClass`.
- The *vnode-runtime-class-sync-with-vnode-launcher* `VirtualClusterTemplate` 

## Privilege Escalation vNode Demo

This demo shows how easy it is to breakout of a privileged container while also showing that the same type of breakout is not possible with vNode.

### Show that the vNode looks privileged

- shell into the `breakout-test-vnode` `pod` that is configured with the `vnode` `runtimeClass`
- run `whoami` and run `pstree -p` to show the reduced process tree
- change directory to what seems like the node's real root directory - `/proc/1/root`
- create a file and show that the file is owned by `root` within the vNode

```
whoami
pstree -p
cd /proc/1/root 
touch i-think-i-am-root
ls -ltr
```

### Switch to the breakout test container without vNode

- shell in the  `breakout-test` (non-vnode) `pod` 
- run `whoami` and run `pstree -p` to show the full `node` process tree
- get the process id of the vnode `pod` lowest level `vnode-container` - it would be **3096** in the example below
- change directory into the root of that process
- list the files and point out that the `i-think-i-am-root` is not owned by `root` outside of the vNode
- show that 

 ```
pstree -p
...
|-vnode-container(2975)-+-vnode-init(3001)-+-vnode-container(3096)-+-pause(3120)
           |                       |                       |                  |-sh(3537)
...
cd /proc/3096/root
ls -ltr
rm i-think-i-am-root
```

### On the physical node switch to root and create a file

```
sudo -i
cd /
touch i-am-the-real-root-do-not-delete
ls -ltr
```

### Switch to the breakout test container without vNode

```
cd /proc/1/root
ls -ltr
rm i-am-the-real-root-do-not-delete
```

### Back on the physical node as root, show that the file was delete

```
ls -ltr
```

## Compare Performance

TODO

```
crictl stats

```
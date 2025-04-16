# vNode with vCluster

vNode enhances the tenant separation already provided by vCluster by providing strong node-level isolation through Linux user namespaces and seccomp filters for vCluster workloads.

Enabling this use case for the demo environment will create:

- The *vcluster-pss-baseline-vnode-config* `VirtualClusterTemplate` that provides a configuration with Pod Security Standards configured for the vCluster control plane Kubernetes API server Pod Security Admission Controller. The configuration is passed to the vCluster Kubernetes kube-apiserver via the *pod-security-admission-config* `ConfigMap` configured as part of the template. The passed in Kubernetes API Server `AdmissionConfiguration`, for the `PodSecurity` plugin `PodSecurityConfiguration`, enforces the **Baseline Pod Security Standards** policy with an exception for vCluster workloads using the `vnode` `runtimeClass`.
- The *vnode-runtime-class-sync-with-vnode-launcher* `VirtualClusterTemplate` 

## Privilege Escalation

- shell into the `pod` configured with the `vnode` `runtimeClass`
- run `whoami` and run `pstree -p` to show the reduced process tree

```
whoami
pstree -p
cd /proc/1/root 
touch i-am-root-do-not-delete
ls -ltr
```

### switch to the breakout test container without vNode

Run the following and get the process id for the vNode `sh` 

 ```
pstree -p
...
|-vnode-container(2975)-+-vnode-init(3001)-+-vnode-container(3096)-+-pause(3120)
           |                       |                       |                  |-sh(3537)



cd /proc/{sh-process-from-above}/root
ls -ltr
rm i-am-root-do-not-delete

```

### on the physical node switch to root and create a file

sudo -i
cd /
touch i-am-really-root-do-not-delete
ls -ltr

# switch to the breakout test container without vNode
cd /proc/1/root
ls -ltr
rm i-am-really-root-do-not-delete

# back on the physical node as root, show that the file was delete
ls -ltr

## Compare Performance

```
crictl stats

```
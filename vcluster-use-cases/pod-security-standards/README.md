# Using Pod Security Standards with vCluster

Enabling this use case for the demo environment will create:

- A **Virtual Cluster Template** that deploys a vCluster with Pod Security Standards configured via the Kubernetes API server Pod Security Admission Controller configuration passed to the vCluster Kubernetes kube-apiserver via the *pod-security-admission-config* `ConfigMap` configured as part of the template.
- A Kubernetes API Server `AdmissionConfiguration` for the `PodSecurity` plugin `PodSecurityConfiguration` that enforces the Baseline Pod Security Standards policy with an exception when using the `vnode` `runtimeClass`.

Example of a vCluster configuration to pass the `AdmissionConfiguration` to the vCluster API server:
```
controlPlane:
    distro:
      k8s:
        apiServer:
        # The admission-control-config-file is passed as a ConfigMap mounted to a the vCluster syncer container
        extraArgs:
            - "--admission-control-config-file=/etc/kubernetes/pod-security-admission-config.yaml"
    statefulSet:
      persistence:
        addVolumes:
        - name: pod-security-admission-config
            configMap:
            name: pod-security-admission-config
        addVolumeMounts:
        - name: pod-security-admission-config
            mountPath: /etc/kubernetes
            readOnly: true
```



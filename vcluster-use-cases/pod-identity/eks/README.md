# vCluster with EKS Pod Identity (ACK `PodIdentityAssociation` Integration)

This guide shows how to declaratively enable **EKS Pod Identity** inside a vCluster by syncing the AWS Controllers for Kubernetes (ACK) EKS `PodIdentityAssociation` custom resource from the vCluster to the host cluster.  

It provides a fully working example that:

- Syncs `ServiceAccounts` and `PodIdentityAssociation` resources from the vCluster to the host.
- Patches fields so ACK applies associations to the correct **host namespace** and vCluster syncer **translated ServiceAccount name**.
- Uses a **VirtualClusterTemplate** with dynamic `clusterName` derived from cluster annotations.
- Verifies Pod Identity credentials with a simple **S3 read/write test** Deployment.

## VirtualClusterTemplate Configuration

In your `VirtualClusterTemplate`, enable syncing of **ServiceAccounts** and **PodIdentityAssociation** custom resources to the host cluster.  
Add patches to dynamically inject the EKS cluster name and to rewrite fields so ACK can correctly bind to the translated host ServiceAccount. A complete `VirtualClusterTemplate` [example is available here](./manifests/pod-identity-template.yaml).

```yaml
sync:
  toHost:
    # Sync ServiceAccounts (required for Pod Identity)
    serviceAccounts:
      enabled: true

    # Sync ACK EKS PodIdentityAssociation CRs
    customResources:
      podidentityassociations.eks.services.k8s.aws/v1alpha1:
        enabled: true
        patches:
          # 1️⃣ Rewrite spec.serviceAccount → translated host SA name
          - path: spec.serviceAccount
            reference:
              apiVersion: v1
              kind: ServiceAccount

          # 2️⃣ Keep spec.namespace aligned with vCluster namespace
          - path: spec.namespace
            expression: "context.vcluster.namespace"

          # 3️⃣ Inject cluster name from Cluster annotation
          - path: spec.clusterName
            expression: {{ get .Values.loft.clusterAnnotations "demos.vcluster.com/eks-cluster-name" | default "" | squote }}
```

When a Cluster has the annotation:

```yaml
metadata:
  annotations:
    demos.vcluster.com/eks-cluster-name: vcp-eks
```

…the rendered VirtualClusterInstance will include:

```yaml
- path: spec.clusterName
  expression: "vcp-eks"
```

This means every `PodIdentityAssociation` synced from the vCluster will be automatically associated with the correct EKS cluster on the host.

## Host Cluster Prerequisites

On the host EKS cluster:

1. The ACK EKS controller must be installed and running.
2. The PodIdentityAssociation CRD (eks.services.k8s.aws/v1alpha1) must be present.
3. An IAM role exists for Pod Identity (e.g. `arn:aws:iam::<AWS_ACCOUNT_ID>:role/vcluster-s3-snapshots`)

## vCluster Resources (Applied Inside the vCluster)

Create a `VirtualClusterInstance` from the **pod-identity-sync** `VirtualClusterTemplate` and once it is up and running, apply the [s3-deploy.yaml](./manifests/s3-deploy.yaml) manifests inside the vCluster after it’s created from your template.

## Verification

After the virtual cluster instance is up and running, use the vcluster CLI to connect to is and run the following commands:

```bash
# Wait for pod readiness
kubectl -n my-app rollout status deploy/s3-podidentity

# Check Pod IdentityAssociation synced to host
kubectl get podidentityassociations.eks.services.k8s.aws -A | grep writer-sa

# View initContainer logs
kubectl -n my-app logs deploy/s3-podidentity -c s3-wait-and-smoke -f
```

Expected successful output:

```bash
Current caller: arn:aws:sts::715841347315:assumed-role/vcluster-s3-snapshots/eks-<pod>
Pod Identity role confirmed.
Uploading to s3://my-vcluster-snapshots-19990/vcluster/<ts>/smoke.txt
ETag: "..."
Read back:
hello from vCluster at <ts>
Success.
```

You can further validate inside the running container:

```bash
kubectl -n my-app exec -it deploy/s3-podidentity -- aws sts get-caller-identity
kubectl -n my-app exec -it deploy/s3-podidentity -- aws s3 ls s3://my-vcluster-snapshots-19990/vcluster/
```

## Key Takeaways

| Key Component | Purpose / Behavior |
|----------------|--------------------|
| **ServiceAccount Sync** | Ensures vCluster ServiceAccounts are automatically created and name-translated in the host namespace, allowing ACK and Pod Identity to reference the correct host SA. |
| **Custom Resource Sync** | Syncs `PodIdentityAssociation` CRs (`eks.services.k8s.aws/v1alpha1`) from the vCluster to the host cluster where the ACK controller runs. |
| **Patch: `spec.serviceAccount`** | Uses a reference patch so vCluster rewrites the ServiceAccount field to the translated host SA name. |
| **Patch: `spec.namespace`** | Uses `context.vcluster.namespace` to align the PIA with the vCluster namespace (and its corresponding host namespace). |
| **Patch: `spec.clusterName`** | Dynamically injected from the cluster annotation (e.g., `demos.vcluster.com/eks-cluster-name`) so the PIA binds to the correct EKS cluster. |
| **ACK Controller (host)** | Reconciles the synced `PodIdentityAssociation` and creates the EKS-level IAM binding between the ServiceAccount and IAM role. |
| **Pod Identity Role (IAM)** | Grants least-privilege permissions to AWS resources (e.g., scoped S3 bucket/prefix access). |
| **Pod Identity Agent (EKS)** | Injects container credentials via the `AWS_CONTAINER_CREDENTIALS_FULL_URI` and projected token, enabling STS assume-role for pods. |
| **AWS CLI Deployment** | Validates Pod Identity end-to-end: waits for correct STS role, writes/reads to S3, and confirms permissions. |
| **IMDS Disabled** | `AWS_EC2_METADATA_DISABLED=true` ensures the pod never falls back to node instance role credentials. |
| **Declarative & GitOps-Friendly** | Entire setup—Pod Identity, ACK, and vCluster—is driven from a `VirtualClusterTemplate` with no manual configuration required inside the vCluster. |

## Summary

With this approach:

- Pod Identity setup for virtual cluster instances are fully declarative.
- ACK automatically manages the `PodIdentityAssociation` lifecycle on the host.
- vCluster patches ensure seamless `ServiceAccount` and `namespace` translation.
- Each vCluster tenant can have its own IAM role for least-privilege access.
- Works out-of-the-box with any IAM-based AWS service.

This method is simpler and more robust than manual annotation-based Pod Identity setup, as it integrates vCluster, ACK, and EKS Pod Identity through native declarative workflows.

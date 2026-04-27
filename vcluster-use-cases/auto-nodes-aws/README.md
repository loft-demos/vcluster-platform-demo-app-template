# Auto Nodes

This use case demonstrates vCluster Platform Auto Nodes backed by an AWS EC2 Terraform `NodeProvider`.

It installs an AWS-focused `NodeProvider`, an `ExternalSecret` for AWS credentials, and an Auto Nodes `VirtualClusterTemplate`.
The EC2-backed demo `VirtualClusterInstance` is kept as a manual example so the surrounding demo environment is not deleted before the inner platform has a chance to clean up AWS resources.

## Business Value

This pattern gives platform teams a cleaner way to offer isolated Kubernetes environments without asking every team to pre-provision fixed worker capacity. Instead of keeping dedicated nodes running for low-traffic or bursty vClusters, compute can be added on demand through the Auto Nodes flow. That helps reduce idle EC2 spend while still letting teams scale into larger instance types when a workload actually needs them.

It also improves the self-service story. Application teams can request a vCluster from a standard template, choose a Kubernetes version, and raise or lower the Auto Nodes pool limit without learning the underlying AWS provisioning details. For the platform team, the Terraform `NodeProvider`, the AWS region choice, and the credentials flow stay centralized and auditable, while GitOps and ESO keep the operational path repeatable and safer than passing static cloud credentials around by hand.

## Prerequisite: ESO

This path depends on the `external-secrets-operator` use case.

- The AWS credentials are not stored in Git.
- [`manifests/aws-ec2-node-provider-credentials.yaml`](./manifests/aws-ec2-node-provider-credentials.yaml) creates an `ExternalSecret` in `vcluster-platform`.
- That `ExternalSecret` reads from `ClusterSecretStore/vcp-demo-store`, which is created by the ESO use case.
- The expected remote keys are:

```text
aws-ec2-node-provider-credentials/AWS_ACCESS_KEY_ID
aws-ec2-node-provider-credentials/AWS_SECRET_ACCESS_KEY
```

To avoid the usual bootstrap race when ESO CRDs are still being registered:

- [`manifests/eso-api-readiness-job.yaml`](./manifests/eso-api-readiness-job.yaml) runs as an Argo CD `PreSync` hook and waits until the `ExternalSecret` and `ClusterSecretStore` APIs are discoverable.
- [`apps/auto-nodes-aws-manifests.yaml`](./apps/auto-nodes-aws-manifests.yaml) also enables `SkipDryRunOnMissingResource=true`, so Argo CD does not fail dry-run while ESO is still coming up.

## What Gets Installed

- [`manifests/aws-ec2-node-provider.yaml`](./manifests/aws-ec2-node-provider.yaml) defines `aws-ec2-node-provider`, a Terraform-backed AWS EC2 `NodeProvider`
- [`manifests/aws-ec2-node-provider-credentials.yaml`](./manifests/aws-ec2-node-provider-credentials.yaml) renders the AWS credential `Secret` from ESO
- [`manifests/auto-nodes-aws-template.yaml`](./manifests/auto-nodes-aws-template.yaml) defines `auto-nodes-aws-template`, a vCluster template with `privateNodes.autoNodes` enabled
- [`examples/auto-nodes-aws-vcluster.yaml`](./examples/auto-nodes-aws-vcluster.yaml) is a manual example `VirtualClusterInstance` for the live demo step

## AWS NodeProvider Details

The `NodeProvider` is configured as follows:

- Region: `us-east-1`
- Terraform source repo: `https://github.com/loft-sh/vcluster-auto-nodes-aws.git`
- Source tag: `v0.1.1`
- Cloud-controller-manager integration flag: `vcluster.com/ccm-enabled: "true"`

Included EC2 instance types:

- `t3.small` with `2` vCPU and `2Gi` memory
- `t3.medium` with `2` vCPU and `4Gi` memory
- `t3.large` with `2` vCPU and `8Gi` memory
- `t3.xlarge` with `4` vCPU and `16Gi` memory
- `t3.2xlarge` with `8` vCPU and `32Gi` memory

Each node type sets `terraform.vcluster.com/credentials: '*'`, so the provider can consume the rendered AWS credential `Secret`.

## Auto Nodes Template

[`manifests/auto-nodes-aws-template.yaml`](./manifests/auto-nodes-aws-template.yaml) creates a `VirtualClusterTemplate` named `auto-nodes-aws-template`.

Important behavior:

- Uses embedded etcd
- Enables `privateNodes`
- Configures one dynamic Auto Nodes pool named `node-pool-1`
- Uses `aws-ec2-node-provider` as the Auto Nodes provider
- Seeds a demo namespace and a scale-up `Deployment` with `0` replicas
- Exposes `k8sVersion` and `autoNodeCount` as template parameters

The embedded demo `Deployment` is intentionally sized so it will not fit on `t3.small`. When you scale it from `0` to `1`, the scheduler should need a `t3.medium` or larger Auto Node because the pod requests `1500m` CPU and `3Gi` memory.

Supported `autoNodeCount` values:

- `1`
- `3`
- `5`

Supported Kubernetes versions currently exposed by the template:

- `v1.35.4`
- `v1.34.7`
- `v1.33.11`
- `v1.32.13`

## Demo Instance

[`examples/auto-nodes-aws-vcluster.yaml`](./examples/auto-nodes-aws-vcluster.yaml) defines a demo `VirtualClusterInstance` named `auto-nodes-aws-demo` in `p-default`.

It is intentionally not part of the default GitOps-managed `manifests/` path.
That keeps the base use case safer for:

- the managed demo-generator flow, where deleting the outer demo environment can remove the inner vCluster Platform before AWS cleanup finishes
- the self-contained `vind` flow, where deleting the whole management cluster would have the same orphaning risk

It references:

- template: `auto-nodes-aws-template`
- version: `1.0.x`
- cluster: `loft-cluster`
- parameters:

```yaml
k8sVersion: v1.33.0
autoNodeCount: "3"
```

Create it manually when you want to run the live demo:

```bash
kubectl apply -f vcluster-use-cases/auto-nodes-aws/examples/auto-nodes-aws-vcluster.yaml
```

Delete it manually before deleting the surrounding demo environment:

```bash
kubectl -n p-default delete virtualclusterinstance auto-nodes-aws-demo --wait=true
```

Wait until the `auto-nodes-aws-demo` vCluster is fully gone in vCluster Platform before deleting the parent demo environment or running `vind-demo-cluster/delete-vind.sh`.

## Enable

For managed or self-managed environments:

```bash
kubectl -n argocd label secret cluster-local eso=true autoNodesAWS=true --overwrite
```

## Scale-Up Demo

After the `auto-nodes-aws-demo` vCluster is ready, connect to it and scale the embedded demo workload:

```bash
kubectl -n auto-nodes-demo scale deploy/scale-up-medium-demo --replicas=1
```

That pod is sized to exceed the `t3.small` node type, so this scale-up should trigger provisioning of a larger Auto Node, typically `t3.medium` or larger depending on the effective allocatable resources and scheduling constraints.

## Notes

- This AWS path is separate from the older `private-nodes/auto-nodes` pod-node flow.
- If ESO is disabled or `vcp-demo-store` is missing, the AWS credentials `ExternalSecret` will not reconcile.
- If you change the provider region from `us-east-1`, update the `NodeProvider` manifest rather than only documenting the change.
- vCluster Platform's Terraform provider destroys nodes when the vCluster is deleted, but that cleanup still depends on the platform staying alive long enough to reconcile the deletion. That is why the AWS demo vCluster is manual rather than auto-created by GitOps here.

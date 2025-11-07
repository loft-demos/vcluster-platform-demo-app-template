# ACK EKS Controller Example Deployment

## Bind the ACK EKS controller K8s `ServiceAccount` to a controller IAM role via Pod Identity

```bash
REGION=us-east-2
EKS_CLUSTER_NAME=vcp-eks
NS_CTRL=ack-system # ACK helm install default
SA_CTRL=ack-eks-controller # ACK EKS helm install default
ROLE_CTRL=ack-eks-controller-role
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Trust policy
cat > trust-policy.json <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "pods.eks.amazonaws.com" },
    "Action": ["sts:AssumeRole","sts:TagSession"]
  }]
}
JSON

aws iam create-role --role-name "$ROLE_CTRL" \
  --assume-role-policy-document file://trust-policy.json

aws eks create-pod-identity-association \
--EKS_CLUSTER_NAME-name "$EKS_CLUSTER_NAME" --region "$REGION" \
--namespace "$NS_CTRL" --service-account "$SA_CTRL" \
--role-arn "$ROLE_CTRL_ARN"
```

## Create inline policy to allow creating/deleting/listing Pod Identity associations for the ACK EKS Controller Role

```bash
cat > policy.json <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PIAOpsOnEKS_CLUSTER_NAME",
      "Effect": "Allow",
      "Action": [
        "eks:CreatePodIdentityAssociation",
        "eks:ListPodIdentityAssociations",
        "eks:DescribePodIdentityAssociation",
        "eks:DeletePodIdentityAssociation",
        "eks:TagResource"
      ],
      "Resource": [
        "arn:aws:eks:us-east-2:$AWS_ACCOUNT_ID:EKS_CLUSTER_NAME/$EKS_CLUSTER_NAME",
        "arn:aws:eks:us-east-2:$AWS_ACCOUNT_ID:podidentityassociation/$EKS_CLUSTER_NAME/*"
      ]
    },
    {
      "Sid": "PassWorkloadRolesOnlyToEKS",
      "Effect": "Allow",
      "Action": [ "iam:PassRole", "iam:GetRole" ],
      "Resource": [
        "arn:aws:iam::$AWS_ACCOUNT_ID:role/vcluster-*-snapshots",
        "arn:aws:iam::$AWS_ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole*"
      ],
      "Condition": {
        "StringEquals": { "iam:PassedToService": "eks.amazonaws.com" }
      }
    }
  ]
}
JSON

aws iam put-role-policy \
  --role-name ack-eks-controller-role \
  --policy-name ack-eks-podidentity-admin \
  --policy-document file://policy.json
```

## Install the ACK EKS Controller with Helm

```bash
aws ecr-public get-login-password --region $REGION \
  | helm registry login --username AWS --password-stdin public.ecr.aws

SERVICE=eks
RELEASE_VERSION=$(curl -sL https://api.github.com/repos/aws-controllers-k8s/${SERVICE}-controller/releases/latest \
  | jq -r '.tag_name | ltrimstr("v")')

helm install --create-namespace -n ack-system ack-${SERVICE}-controller \
  oci://public.ecr.aws/aws-controllers-k8s/${SERVICE}-chart \
  --version=${RELEASE_VERSION} \
  --set aws.region=${REGION}
```

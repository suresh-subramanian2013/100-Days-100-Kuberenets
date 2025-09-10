# Day 8: EKS + Karpenter Auto-Scaling Demo

Simple demo showing Karpenter auto-scaling: start with 4 pods, scale to 20, watch Karpenter create new EC2 instances automatically.

## Prerequisites

- AWS CLI configured
- kubectl
- eksctl
- Helm

## Quick Setup

### Step 1: Create EKS Cluster

```bash
# Set variables
export CLUSTER_NAME="demo-cluster"
export AWS_REGION="us-east-1"

# Create EKS cluster with 1 node
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --version 1.29 \
  --with-oidc \
  --managed \
  --nodes 1 \
  --node-type t3.medium

# Verify cluster
kubectl get nodes
```

### Step 2: Setup IAM for Karpenter

```bash
# Get account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create Karpenter node role
aws iam create-role \
  --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {"Service": "ec2.amazonaws.com"},
        "Action": "sts:AssumeRole"
      }
    ]
  }'

# Attach required policies to node role
aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam attach-role-policy --role-name "KarpenterNodeRole-${CLUSTER_NAME}" --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Create Karpenter controller policy
aws iam create-policy \
  --policy-name "KarpenterControllerPolicy-${CLUSTER_NAME}" \
  --policy-document file://karpenter-controller-policy.json

# Create controller service account with IAM role
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=karpenter \
  --name=karpenter \
  --role-name="KarpenterControllerRole-${CLUSTER_NAME}" \
  --attach-policy-arn="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}" \
  --approve
```

### Step 3: Install Karpenter

```bash
# Add Helm repo
helm repo add karpenter https://charts.karpenter.sh/
helm repo update

# Get cluster endpoint
CLUSTER_ENDPOINT=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.endpoint" --output text)

# Install Karpenter v0.37.0 (latest stable)
helm upgrade --install karpenter karpenter/karpenter \
  --namespace karpenter \
  --create-namespace \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterControllerRole-${CLUSTER_NAME}" \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.clusterEndpoint=${CLUSTER_ENDPOINT}" \
  --version 0.37.0 \
  --wait

# Verify installation
kubectl get pods -n karpenter
```

### Step 4: Tag Resources for Discovery

```bash
# Tag subnets for Karpenter discovery
SUBNETS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.subnetIds" --output text)
for subnet in $SUBNETS; do
    aws ec2 create-tags --resources $subnet --tags Key=karpenter.sh/discovery,Value=$CLUSTER_NAME
done

# Tag security group for Karpenter discovery
SECURITY_GROUP=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)
aws ec2 create-tags --resources $SECURITY_GROUP --tags Key=karpenter.sh/discovery,Value=$CLUSTER_NAME
```

### Step 5: Apply Karpenter Configuration

```bash
# Apply EC2NodeClass and NodePool (v1beta1 API)
kubectl apply -f karpenter-ec2nodeclass.yaml
kubectl apply -f karpenter-nodepool.yaml

# Verify configuration
kubectl get ec2nodeclass
kubectl get nodepool
```

### Step 6: Deploy Test Application (4 Pods)

```bash
# Deploy nginx with 4 replicas
kubectl apply -f test-deployment.yaml

# Check initial state
kubectl get pods -l app=demo-app
kubectl get nodes
```

### Step 7: Scale to 20 Pods (Trigger Auto-Scaling)

```bash
# Scale up to trigger Karpenter
kubectl scale deployment demo-app --replicas=20

# Watch in separate terminals:
# Terminal 1: Watch pods
kubectl get pods -l app=demo-app -w

# Terminal 2: Watch nodes
kubectl get nodes -w

# Terminal 3: Watch Karpenter logs
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter
```

## What You'll See

1. **Initial**: 1 EKS node + 4 nginx pods
2. **After scaling**: Karpenter creates new EC2 instances within 30-60 seconds
3. **Final**: Multiple nodes with 20 pods distributed across them

## Monitoring Commands

```bash
# Check pod distribution across nodes
kubectl get pods -l app=demo-app -o wide

# Check Karpenter-managed nodes
kubectl get nodes -l karpenter.sh/nodepool

# View Karpenter events
kubectl get events -n karpenter --sort-by=.metadata.creationTimestamp
```

## Cleanup

```bash
# Delete deployment (Karpenter will remove unused nodes automatically)
kubectl delete -f test-deployment.yaml

# Wait a few minutes, then delete cluster
eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION
```

This demo shows Karpenter's core value: automatic, fast EC2 provisioning based on actual pod requirements.

# Day 8: EKS + Karpenter Auto-Scaling Demo

## What is Karpenter?

Karpenter is an open-source, high-performance Kubernetes cluster autoscaler that provisions compute resources in seconds, not minutes. Unlike traditional cluster autoscalers that work with pre-defined node groups, Karpenter directly provisions individual EC2 instances that are optimally sized and configured for your workloads.

### Key Benefits

- **Fast Provisioning**: New nodes ready in ~30 seconds vs 3-5 minutes with traditional autoscalers
- **Cost Optimization**: Automatically selects the most cost-effective instance types from 600+ options
- **Flexible Scheduling**: No need to pre-define node groups - provisions exactly what your pods need
- **Intelligent Bin Packing**: Efficiently schedules pods to minimize waste and cost
- **Automatic Deprovisioning**: Removes unused nodes within 30 seconds of becoming empty

### How Karpenter Works

1. **Pod Scheduling**: When pods can't be scheduled due to resource constraints
2. **Instance Selection**: Karpenter evaluates 600+ EC2 instance types to find the best fit
3. **Rapid Provisioning**: Launches optimally-sized instances in ~30 seconds
4. **Automatic Cleanup**: Removes nodes when they're no longer needed

This demo shows Karpenter in action: scale up deployment to trigger auto-scaling, watch Karpenter create new EC2 instances automatically.

## Prerequisites

- AWS CLI configured
- kubectl
- eksctl
- Helm

## Quick Setup

### Step 1: Set Environment Variables

```bash
export KARPENTER_NAMESPACE="karpenter"
export KARPENTER_VERSION="1.6.3"
export K8S_VERSION="1.31"
export CLUSTER_NAME="demo-cluster"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export TEMPOUT="$(mktemp)"
export ARM_AMI_ID="$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/${K8S_VERSION}/amazon-linux-2-arm64/recommended/image_id --query Parameter.Value --output text)"
export AMD_AMI_ID="$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/${K8S_VERSION}/amazon-linux-2/recommended/image_id --query Parameter.Value --output text)"
export GPU_AMI_ID="$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/${K8S_VERSION}/amazon-linux-2-gpu/recommended/image_id --query Parameter.Value --output text)"
export AWS_PARTITION="aws"
export ALIAS_VERSION="v20241212"
```

### Step 2: Create CloudFormation Stack

```bash
# Download and deploy CloudFormation template
curl -fsSL https://raw.githubusercontent.com/aws/karpenter-provider-aws/v"${KARPENTER_VERSION}"/website/content/en/preview/getting-started/getting-started-with-karpenter/cloudformation.yaml > "${TEMPOUT}" \
&& aws cloudformation deploy \
  --stack-name "Karpenter-${CLUSTER_NAME}" \
  --template-file "${TEMPOUT}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "ClusterName=${CLUSTER_NAME}"
```

### Step 3: Create EKS Cluster

```bash
# Create EKS cluster with eksctl
eksctl create cluster -f - <<EOF
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_DEFAULT_REGION}
  version: "${K8S_VERSION}"
  tags:
    karpenter.sh/discovery: ${CLUSTER_NAME}

iam:
  withOIDC: true
  podIdentityAssociations:
  - namespace: "${KARPENTER_NAMESPACE}"
    serviceAccountName: karpenter
    roleName: ${CLUSTER_NAME}-karpenter
    permissionPolicyARNs:
    - arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}

iamIdentityMappings:
- arn: "arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME}"
  username: system:node:{{EC2PrivateDNSName}}
  groups:
  - system:bootstrappers
  - system:nodes

managedNodeGroups:
- instanceType: m5.large
  amiFamily: AmazonLinux2023
  name: ${CLUSTER_NAME}-ng
  desiredCapacity: 2
  minSize: 1
  maxSize: 10

addons:
- name: eks-pod-identity-agent
EOF

# Set cluster endpoint and IAM role ARN
export CLUSTER_ENDPOINT="$(aws eks describe-cluster --name "${CLUSTER_NAME}" --query "cluster.endpoint" --output text)"
export KARPENTER_IAM_ROLE_ARN="arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-karpenter"

echo "Cluster Endpoint: ${CLUSTER_ENDPOINT}"
echo "Karpenter IAM Role ARN: ${KARPENTER_IAM_ROLE_ARN}"
```

### Step 4: Create EC2 Spot Service Linked Role

```bash
# Create service linked role for EC2 Spot (if not already exists)
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true
```

### Step 5: Install Karpenter

```bash
# Logout of helm registry and install Karpenter
helm registry logout public.ecr.aws

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version "${KARPENTER_VERSION}" --namespace "${KARPENTER_NAMESPACE}" --create-namespace \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.interruptionQueue=${CLUSTER_NAME}" \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.limits.cpu=1 \
  --set controller.resources.limits.memory=1Gi \
  --wait

# Verify installation
kubectl get pods -n "${KARPENTER_NAMESPACE}"
```

### Step 6: Create NodePool and EC2NodeClass

```bash
# Apply NodePool and EC2NodeClass configurations
cat <<EOF | envsubst | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      expireAfter: 720h # 30 * 24h = 720h
  limits:
    cpu: 1000
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: "KarpenterNodeRole-${CLUSTER_NAME}"
  amiSelectorTerms:
    - alias: "al2023@${ALIAS_VERSION}"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
EOF

# Verify configuration
kubectl get nodepool
kubectl get ec2nodeclass
```

### Step 7: Deploy Test Application

```bash
# Deploy test application with pause container
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      terminationGracePeriodSeconds: 0
      securityContext:
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
      containers:
      - name: inflate
        image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        resources:
          requests:
            cpu: 1
        securityContext:
          allowPrivilegeEscalation: false
EOF

# Check initial state
kubectl get pods -l app=inflate
kubectl get nodes
```

### Step 8: Scale Up to Trigger Auto-Scaling

```bash
# Scale up to trigger Karpenter
kubectl scale deployment inflate --replicas 5

# Watch Karpenter logs in real-time
kubectl logs -f -n "${KARPENTER_NAMESPACE}" -l app.kubernetes.io/name=karpenter -c controller

# In separate terminals, watch:
# Terminal 1: Watch pods
kubectl get pods -l app=inflate -w

# Terminal 2: Watch nodes
kubectl get nodes -w
```

### Step 9: Scale Down and Observe Consolidation

```bash
# Delete deployment to trigger node consolidation
kubectl delete deployment inflate

# Watch Karpenter logs to see node termination
kubectl logs -f -n "${KARPENTER_NAMESPACE}" -l app.kubernetes.io/name=karpenter -c controller
```

## What You'll See

### Phase 1: Initial State
- 2 EKS managed nodes from the node group
- Cluster operating normally with existing capacity

### Phase 2: Scaling Event
- Scale deployment from 0 to 5 replicas
- 5 new pods enter "Pending" state (insufficient capacity due to CPU requests)
- Karpenter detects unschedulable pods

### Phase 3: Karpenter in Action
- Analyzes pod requirements (CPU: 1 core per pod)
- Evaluates 600+ EC2 instance types for optimal fit
- Provisions new instances in ~30 seconds
- New pods automatically scheduled on fresh nodes

### Phase 4: Consolidation
- Delete deployment to remove workload
- Karpenter automatically terminates unused nodes within 1 minute
- Cost optimization through intelligent resource management

## Karpenter vs Traditional Autoscaling

| Feature | Karpenter | Traditional ASG |
|---------|-----------|-----------------|
| Provisioning Speed | ~30 seconds | 3-5 minutes |
| Instance Selection | 600+ types, automatic | Pre-defined node groups |
| Cost Optimization | Continuous, intelligent | Manual configuration |
| Scheduling Flexibility | Pod-level requirements | Node group constraints |
| Operational Overhead | Minimal | High (managing node groups) |

## Monitoring Commands

```bash
# Check pod distribution across nodes
kubectl get pods -l app=inflate -o wide

# Check Karpenter-managed nodes
kubectl get nodes -l karpenter.sh/nodepool

# View Karpenter events
kubectl get events -n "${KARPENTER_NAMESPACE}" --sort-by=.metadata.creationTimestamp

# Delete specific Karpenter node manually (if needed)
kubectl delete node "${NODE_NAME}"
```

## Cleanup

```bash
# Delete deployment (Karpenter will remove unused nodes automatically)
kubectl delete deployment inflate

# Wait a few minutes for node consolidation, then delete cluster
eksctl delete cluster --name "${CLUSTER_NAME}" --region "${AWS_DEFAULT_REGION}"

# Delete CloudFormation stack
aws cloudformation delete-stack --stack-name "Karpenter-${CLUSTER_NAME}"
```

## Manual Node Management

### Delete Karpenter Nodes Manually
If you delete a node with kubectl, Karpenter will gracefully cordon, drain, and shutdown the corresponding instance:

```bash
# List Karpenter-managed nodes
kubectl get nodes -l karpenter.sh/nodepool

# Delete a specific node (replace with actual node name)
kubectl delete node "${NODE_NAME}"

# Karpenter will:
# 1. Add a finalizer to prevent immediate deletion
# 2. Cordon the node to prevent new pods
# 3. Drain existing pods gracefully
# 4. Terminate the EC2 instance
# 5. Remove the finalizer and complete deletion
```

## Advanced Karpenter Features

### Spot Instance Support
Karpenter can automatically use Spot instances for cost savings up to 90%:
```yaml
# In NodePool spec
requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["spot", "on-demand"]
```

### Multi-Architecture Support
Supports both x86 and ARM-based instances (Graviton):
```yaml
requirements:
  - key: kubernetes.io/arch
    operator: In
    values: ["amd64", "arm64"]
```

### Taints and Tolerations
Automatically applies taints for specialized workloads:
```yaml
taints:
  - key: example.com/special-workload
    value: "true"
    effect: NoSchedule
```

## Troubleshooting

### Common Issues

1. **Pods stuck in Pending**: Check NodePool requirements and pod resource requests
2. **Slow provisioning**: Verify subnet tags and security group configuration
3. **Nodes not terminating**: Check for pods without proper disruption policies

### Debug Commands
```bash
# Check Karpenter controller logs
kubectl logs -f -n karpenter -c controller -l app.kubernetes.io/name=karpenter

# View NodePool status
kubectl describe nodepool default

# Check node provisioning events
kubectl get events --field-selector reason=Provisioned
```

## Production Considerations

- **Resource Limits**: Set appropriate CPU/memory limits on pods
- **Pod Disruption Budgets**: Ensure graceful node termination
- **Monitoring**: Use CloudWatch metrics for cost and performance tracking
- **Security**: Regularly update Karpenter and review IAM permissions
- **Backup Strategy**: Plan for node replacement scenarios

This demo showcases Karpenter's revolutionary approach to Kubernetes autoscaling - delivering the speed, flexibility, and cost optimization that modern containerized applications demand.

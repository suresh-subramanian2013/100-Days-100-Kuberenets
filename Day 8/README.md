# Day 8: AWS EKS + Karpenter Complete Setup

Welcome to Day 8 of the 100 Days of Kubernetes journey! This day covers setting up AWS EKS with Karpenter for automatic node provisioning and scaling.

## Overview

Karpenter is a Kubernetes cluster autoscaler that provisions nodes based on pod requirements. It's designed to be fast, efficient, and cost-effective, replacing the traditional Cluster Autoscaler.

## Prerequisites Setup for Windows

### 1. Install Required Tools

#### Install AWS CLI
```powershell
# Download and install AWS CLI v2
$url = "https://awscli.amazonaws.com/AWSCLIV2.msi"
$output = "$env:TEMP\AWSCLIV2.msi"
Invoke-WebRequest -Uri $url -OutFile $output
Start-Process msiexec.exe -Wait -ArgumentList "/I $output /quiet"

# Verify installation
aws --version
```

#### Install kubectl
```powershell
# Download kubectl
$url = "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
$output = "$env:USERPROFILE\kubectl.exe"
Invoke-WebRequest -Uri $url -OutFile $output

# Add to PATH (run as Administrator)
$path = [Environment]::GetEnvironmentVariable("PATH", "Machine")
$newPath = "$path;$env:USERPROFILE"
[Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")

# Verify installation
kubectl version --client
```

#### Install eksctl
```powershell
# Download eksctl
$url = "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Windows_amd64.zip"
$output = "$env:TEMP\eksctl.zip"
Invoke-WebRequest -Uri $url -OutFile $output

# Extract and install
Expand-Archive -Path $output -DestinationPath "$env:USERPROFILE\eksctl"
Move-Item "$env:USERPROFILE\eksctl\eksctl.exe" "$env:USERPROFILE\eksctl.exe"

# Add to PATH (if not already added)
$path = [Environment]::GetEnvironmentVariable("PATH", "User")
$newPath = "$path;$env:USERPROFILE"
[Environment]::SetEnvironmentVariable("PATH", $newPath, "User")

# Verify installation
eksctl version
```

#### Install Helm
```powershell
# Download Helm
$url = "https://get.helm.sh/helm-v3.12.0-windows-amd64.zip"
$output = "$env:TEMP\helm.zip"
Invoke-WebRequest -Uri $url -OutFile $output

# Extract and install
Expand-Archive -Path $output -DestinationPath "$env:TEMP\helm"
Move-Item "$env:TEMP\helm\windows-amd64\helm.exe" "$env:USERPROFILE\helm.exe"

# Verify installation
helm version
```

### 2. Configure AWS Credentials
```powershell
# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region (us-east-1), and output format (json)

# Verify configuration
aws sts get-caller-identity
```

## Step-by-Step EKS + Karpenter Setup

### Step 1: Create IAM Roles for Karpenter

#### Create Karpenter Node Role
```powershell
# Create the node role
aws iam create-role --role-name KarpenterNodeRole-demo-cluster --assume-role-policy-document '{\"Version\": \"2012-10-17\", \"Statement\": [{\"Effect\": \"Allow\", \"Principal\": {\"Service\": \"ec2.amazonaws.com\"}, \"Action\": \"sts:AssumeRole\"}]}'

# Attach required policies
aws iam attach-role-policy --role-name KarpenterNodeRole-demo-cluster --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name KarpenterNodeRole-demo-cluster --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam attach-role-policy --role-name KarpenterNodeRole-demo-cluster --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

# Create instance profile
aws iam create-instance-profile --instance-profile-name KarpenterNodeInstanceProfile-demo-cluster

# Add role to instance profile
aws iam add-role-to-instance-profile --instance-profile-name KarpenterNodeInstanceProfile-demo-cluster --role-name KarpenterNodeRole-demo-cluster
```

#### Create Karpenter Controller Role (will be updated after cluster creation)
```powershell
# This will be created after EKS cluster is ready with proper OIDC provider
# Placeholder for now - will be updated in Step 3
```

### Step 2: Create EKS Cluster
```powershell
# Create EKS cluster with eksctl
eksctl create cluster --name demo-cluster --region us-east-1 --nodes 1 --node-type t3.medium --managed

# Verify cluster creation
kubectl get nodes
aws eks describe-cluster --name demo-cluster --region us-east-1
```

### Step 3: Create Karpenter Controller IAM Role with OIDC
```powershell
# Get OIDC issuer URL
$OIDC_ISSUER = aws eks describe-cluster --name demo-cluster --region us-east-1 --query "cluster.identity.oidc.issuer" --output text
$OIDC_ID = $OIDC_ISSUER.Split('/')[-1]

# Create Karpenter controller role with proper OIDC trust policy
$TRUST_POLICY = @"
{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Principal\": {
        \"Federated\": \"arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/$OIDC_ID\"
      },
      \"Action\": \"sts:AssumeRoleWithWebIdentity\",
      \"Condition\": {
        \"StringEquals\": {
          \"oidc.eks.us-east-1.amazonaws.com/id/$OIDC_ID:sub\": \"system:serviceaccount:karpenter:karpenter\",
          \"oidc.eks.us-east-1.amazonaws.com/id/$OIDC_ID:aud\": \"sts.amazonaws.com\"
        }
      }
    }
  ]
}
"@

# Create the role
aws iam create-role --role-name KarpenterControllerRole-demo-cluster --assume-role-policy-document $TRUST_POLICY

# Create and attach Karpenter policy
aws iam put-role-policy --role-name KarpenterControllerRole-demo-cluster --policy-name KarpenterControllerPolicy --policy-document (Get-Content karpenter-controller-policy.json -Raw)
```

### Step 4: Install Karpenter using Helm
```powershell
# Add Karpenter Helm repository
helm repo add karpenter https://charts.karpenter.sh/
helm repo update

# Get cluster endpoint
$CLUSTER_ENDPOINT = aws eks describe-cluster --name demo-cluster --region us-east-1 --query "cluster.endpoint" --output text

# Install Karpenter
helm upgrade --install karpenter karpenter/karpenter `
  --namespace karpenter `
  --create-namespace `
  --set serviceAccount.create=true `
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/KarpenterControllerRole-demo-cluster" `
  --set clusterName=demo-cluster `
  --set clusterEndpoint=$CLUSTER_ENDPOINT `
  --set aws.defaultInstanceProfile=KarpenterNodeInstanceProfile-demo-cluster `
  --version v0.37.0

# Verify Karpenter installation
kubectl get pods -n karpenter
```

### Step 5: Tag Subnets and Security Groups
```powershell
# Get cluster subnets and security groups
$SUBNETS = aws eks describe-cluster --name demo-cluster --region us-east-1 --query "cluster.resourcesVpcConfig.subnetIds" --output text
$SECURITY_GROUPS = aws eks describe-cluster --name demo-cluster --region us-east-1 --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text

# Tag subnets for Karpenter discovery
foreach ($subnet in $SUBNETS.Split()) {
    aws ec2 create-tags --resources $subnet --tags Key=karpenter.sh/discovery,Value=demo-cluster
}

# Tag security group for Karpenter discovery
aws ec2 create-tags --resources $SECURITY_GROUPS --tags Key=karpenter.sh/discovery,Value=demo-cluster
```

### Step 6: Apply Karpenter Configuration
```powershell
# Apply NodePool and EC2NodeClass
kubectl apply -f karpenter-nodepool.yaml
kubectl apply -f karpenter-ec2nodeclass.yaml

# Verify configuration
kubectl get nodepools
kubectl get ec2nodeclasses
```

### Step 7: Deploy Test Application
```powershell
# Deploy test application that requires scaling
kubectl apply -f test-deployment.yaml

# Watch pods and nodes
kubectl get pods -o wide -w
# In another terminal: kubectl get nodes -w
```

### Step 8: Test Scaling
```powershell
# Scale up to trigger node provisioning
kubectl scale deployment demo-app --replicas=20

# Watch Karpenter logs
kubectl logs -f deployment/karpenter -n karpenter

# Scale down to test node termination
kubectl scale deployment demo-app --replicas=1
```

## Monitoring and Troubleshooting

### Useful Commands
```powershell
# Check Karpenter status
kubectl get pods -n karpenter
kubectl logs deployment/karpenter -n karpenter

# Monitor nodes
kubectl get nodes -l karpenter.sh/nodepool
kubectl describe node <node-name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# View Karpenter metrics
kubectl port-forward -n karpenter svc/karpenter 8000:8000
# Visit http://localhost:8000/metrics
```

### Common Issues and Solutions

1. **Pods stuck in Pending**
   - Check resource requests and limits
   - Verify NodePool requirements
   - Check subnet and security group tags

2. **Karpenter not provisioning nodes**
   - Verify IAM roles and policies
   - Check Karpenter logs for errors
   - Ensure proper OIDC configuration

3. **Nodes not joining cluster**
   - Verify instance profile and role
   - Check security group rules
   - Ensure proper subnet configuration

## Cleanup
```powershell
# Delete test deployment
kubectl delete -f test-deployment.yaml

# Delete Karpenter resources
kubectl delete -f karpenter-nodepool.yaml
kubectl delete -f karpenter-ec2nodeclass.yaml

# Uninstall Karpenter
helm uninstall karpenter -n karpenter

# Delete cluster
eksctl delete cluster --name demo-cluster --region us-east-1

# Delete IAM roles and policies
aws iam remove-role-from-instance-profile --instance-profile-name KarpenterNodeInstanceProfile-demo-cluster --role-name KarpenterNodeRole-demo-cluster
aws iam delete-instance-profile --instance-profile-name KarpenterNodeInstanceProfile-demo-cluster
aws iam detach-role-policy --role-name KarpenterNodeRole-demo-cluster --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam detach-role-policy --role-name KarpenterNodeRole-demo-cluster --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam detach-role-policy --role-name KarpenterNodeRole-demo-cluster --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam delete-role --role-name KarpenterNodeRole-demo-cluster
aws iam delete-role-policy --role-name KarpenterControllerRole-demo-cluster --policy-name KarpenterControllerPolicy
aws iam delete-role --role-name KarpenterControllerRole-demo-cluster
```

## Key Benefits of Karpenter

- **Fast Provisioning**: Nodes ready in ~30 seconds vs 3-5 minutes with Cluster Autoscaler
- **Cost Optimization**: Automatic spot instance usage and right-sizing
- **Simplified Management**: No node group management required
- **Flexible Scheduling**: Advanced scheduling constraints and requirements
- **Efficient Scaling**: Provisions exactly what's needed, when it's needed

## Next Steps

After completing this setup, you'll have a fully functional EKS cluster with Karpenter that can automatically provision and scale nodes based on your workload demands. This provides a solid foundation for running production workloads with optimal cost and performance characteristics.

## ✅ Complete Karpenter Setup Overview

### 📁 File Structure
```
Day 8/
├── README.md                          # Comprehensive documentation
├── karpenter-controller-policy.json   # IAM policy for Karpenter controller
├── karpenter-namespace.yaml          # Karpenter namespace
├── karpenter-serviceaccount.yaml     # Service account with IAM role
├── karpenter-rbac.yaml               # RBAC permissions
├── karpenter-service.yaml            # Karpenter service
├── karpenter-deployment.yaml         # Karpenter controller deployment
├── karpenter-ec2nodeclass.yaml       # EC2 instance configuration
├── karpenter-nodepool.yaml           # Node provisioning rules
├── test-deployment.yaml              # Test application
├── windows-setup.ps1                 # Windows tools installation
├── karpenter-iam-setup.ps1          # IAM roles and policies setup
└── install-karpenter.ps1            # Complete Karpenter installation
```

### 🚀 Key Features

#### Windows PowerShell Scripts
- **`windows-setup.ps1`** - Installs kubectl, eksctl, AWS CLI, Helm via Chocolatey
- **`karpenter-iam-setup.ps1`** - Creates all necessary IAM roles and policies
- **`install-karpenter.ps1`** - Complete automated Karpenter installation

#### Kubernetes YAML Files
- **Modular approach** - Each component in separate files
- **Production-ready** - Proper RBAC, security contexts, resource limits
- **Configurable** - Placeholder values for easy customization

#### Comprehensive Documentation
- **Step-by-step setup** for Windows environments
- **Troubleshooting guide** with common issues and solutions
- **Best practices** for production deployments
- **Monitoring and verification** commands

### 🎯 Quick Usage Guide

#### 1. Setup Windows Environment
```powershell
# Run as Administrator
.\windows-setup.ps1
```

#### 2. Create IAM Roles
```powershell
.\karpenter-iam-setup.ps1 -ClusterName "demo-cluster" -AccountId "471112966640" -Region "us-east-1"
```

#### 3. Install Karpenter
```powershell
.\install-karpenter.ps1 -ClusterName "demo-cluster" -AccountId "471112966640" -Region "us-east-1"
```

#### 4. Test Scaling
```powershell
kubectl apply -f test-deployment.yaml
kubectl get nodes -w
```

### 🔧 Advanced Features
- **Automatic configuration** - Scripts update YAML files with actual values
- **Error handling** - Robust error checking and recovery
- **Security best practices** - IMDSv2, encryption, least privilege
- **Cost optimization** - Spot instances, right-sizing, consolidation
- **Monitoring integration** - Metrics endpoint, logging, events

## 🧪 Karpenter Scale Up/Down Demo

This section provides a comprehensive demo of Karpenter's automatic scaling capabilities.

### Demo Prerequisites
```powershell
# Ensure Karpenter is installed and running
kubectl get pods -n karpenter
kubectl get nodepools
kubectl get ec2nodeclasses

# Check initial cluster state
kubectl get nodes
kubectl get pods --all-namespaces
```

### Phase 1: Scale Up Demo

#### Step 1: Monitor Initial State
```powershell
# Terminal 1: Watch nodes
kubectl get nodes -w

# Terminal 2: Watch Karpenter logs
kubectl logs -f deployment/karpenter -n karpenter

# Terminal 3: Watch pods
kubectl get pods -o wide -w
```

#### Step 2: Deploy Test Application (Small Scale)
```powershell
# Deploy initial test application
kubectl apply -f test-deployment.yaml

# Check pod status
kubectl get pods -l app=karpenter-test
kubectl describe pods -l app=karpenter-test
```

#### Step 3: Trigger Scale Up Event
```powershell
# Scale up to trigger node provisioning
kubectl scale deployment karpenter-test-app --replicas=10

# Watch the magic happen!
# You should see:
# 1. Pods in Pending state
# 2. Karpenter logs showing node provisioning
# 3. New nodes appearing in cluster
# 4. Pods getting scheduled on new nodes
```

#### Step 4: Monitor Scale Up Process
```powershell
# Check pending pods
kubectl get pods -l app=karpenter-test --field-selector=status.phase=Pending

# Check Karpenter events
kubectl get events --sort-by=.metadata.creationTimestamp | grep -i karpenter

# Monitor node provisioning
kubectl get nodes -l karpenter.sh/nodepool=default

# Check node details
kubectl describe node <new-node-name>
```

#### Step 5: Verify Scale Up Success
```powershell
# All pods should be running
kubectl get pods -l app=karpenter-test

# Check resource utilization
kubectl top nodes
kubectl top pods -l app=karpenter-test

# Verify node labels and taints
kubectl get nodes --show-labels | grep karpenter
```

### Phase 2: Scale Down Demo

#### Step 6: Trigger Scale Down Event
```powershell
# Scale down the deployment
kubectl scale deployment karpenter-test-app --replicas=2

# Watch pods being terminated
kubectl get pods -l app=karpenter-test -w
```

#### Step 7: Monitor Node Consolidation
```powershell
# Karpenter will wait for consolidation period (30s by default)
# Watch Karpenter logs for consolidation decisions
kubectl logs -f deployment/karpenter -n karpenter | grep -i consolidat

# Monitor nodes - some should be marked for deletion
kubectl get nodes -l karpenter.sh/nodepool=default
```

#### Step 8: Observe Node Termination
```powershell
# Watch nodes being cordoned and drained
kubectl get nodes -w

# Check events for node termination
kubectl get events --sort-by=.metadata.creationTimestamp | grep -i terminat

# Verify remaining pods are rescheduled
kubectl get pods -l app=karpenter-test -o wide
```

### Phase 3: Advanced Scaling Scenarios

#### Scenario 1: Mixed Instance Types
```powershell
# Create deployment with different resource requirements
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-intensive-app
spec:
  replicas: 5
  selector:
    matchLabels:
      app: cpu-intensive
  template:
    metadata:
      labels:
        app: cpu-intensive
    spec:
      containers:
      - name: cpu-app
        image: nginx
        resources:
          requests:
            cpu: 2000m
            memory: 1Gi
      tolerations:
      - key: karpenter.sh/unschedulable
        operator: Equal
        value: "true"
        effect: NoSchedule
EOF

# Watch Karpenter provision compute-optimized instances
kubectl get nodes -l node.kubernetes.io/instance-type --show-labels
```

#### Scenario 2: Spot vs On-Demand
```powershell
# Deploy workload that can use spot instances
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spot-workload
spec:
  replicas: 8
  selector:
    matchLabels:
      app: spot-workload
  template:
    metadata:
      labels:
        app: spot-workload
    spec:
      nodeSelector:
        karpenter.sh/capacity-type: spot
      containers:
      - name: app
        image: nginx
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
      tolerations:
      - key: karpenter.sh/unschedulable
        operator: Equal
        value: "true"
        effect: NoSchedule
EOF

# Check if spot instances are provisioned
kubectl get nodes -l karpenter.sh/capacity-type=spot
```

### Phase 4: Performance Metrics

#### Monitor Provisioning Speed
```powershell
# Time the provisioning process
$startTime = Get-Date
kubectl scale deployment karpenter-test-app --replicas=15

# Wait for all pods to be running
do {
    $pendingPods = kubectl get pods -l app=karpenter-test --field-selector=status.phase=Pending --no-headers | Measure-Object | Select-Object -ExpandProperty Count
    Start-Sleep 5
} while ($pendingPods -gt 0)

$endTime = Get-Date
$duration = $endTime - $startTime
Write-Host "Provisioning completed in: $($duration.TotalSeconds) seconds"
```

#### Check Cost Optimization
```powershell
# View instance types and pricing
kubectl get nodes -o custom-columns=NAME:.metadata.name,INSTANCE-TYPE:.metadata.labels.'node\.kubernetes\.io/instance-type',CAPACITY-TYPE:.metadata.labels.'karpenter\.sh/capacity-type'

# Check resource utilization efficiency
kubectl top nodes
```

### Phase 5: Cleanup and Reset

#### Clean Up Test Workloads
```powershell
# Delete all test deployments
kubectl delete deployment karpenter-test-app
kubectl delete deployment cpu-intensive-app
kubectl delete deployment spot-workload

# Wait for node consolidation
Start-Sleep 60

# Check remaining nodes
kubectl get nodes -l karpenter.sh/nodepool=default
```

### Demo Verification Checklist

#### ✅ Scale Up Verification
- [ ] Pods were pending due to insufficient capacity
- [ ] Karpenter logs showed node provisioning decisions
- [ ] New nodes appeared within 30-60 seconds
- [ ] Pods were scheduled on new nodes
- [ ] Appropriate instance types were selected

#### ✅ Scale Down Verification
- [ ] Excess nodes were identified for consolidation
- [ ] Nodes were cordoned and drained gracefully
- [ ] Pods were rescheduled to remaining nodes
- [ ] Unused nodes were terminated
- [ ] Cluster returned to minimal footprint

#### ✅ Performance Metrics
- [ ] Node provisioning time < 60 seconds
- [ ] Appropriate instance type selection
- [ ] Cost-effective capacity type usage (spot when possible)
- [ ] Efficient resource utilization
- [ ] No scheduling failures or errors

### Demo Troubleshooting

#### Common Issues During Demo

1. **Pods Stuck in Pending**
   ```powershell
   kubectl describe pod <pod-name>
   # Check for:
   # - Resource requirements vs NodePool limits
   # - Taints and tolerations
   # - Node selectors
   ```

2. **Slow Node Provisioning**
   ```powershell
   kubectl logs deployment/karpenter -n karpenter | grep -i error
   # Check for:
   # - IAM permission issues
   # - Subnet/SG availability
   # - Instance type availability
   ```

3. **Nodes Not Terminating**
   ```powershell
   kubectl get events | grep -i terminat
   # Check for:
   # - PodDisruptionBudgets
   # - Non-graceful pod termination
   # - System pods preventing drainage
   ```

This comprehensive demo showcases Karpenter's intelligent scaling capabilities and provides a hands-on experience with automatic node provisioning and consolidation! 🚀

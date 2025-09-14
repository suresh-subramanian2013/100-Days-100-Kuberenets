# Day 8: Getting Started with Karpenter

## Overview
Karpenter is a Kubernetes cluster autoscaler that automatically provisions new nodes in response to unschedulable pods. It observes events within the Kubernetes cluster and sends commands to the underlying cloud provider to optimize resource allocation.

## Key Features
- **Automatic Node Provisioning**: Responds to unschedulable pods by creating appropriate nodes
- **Cost Optimization**: Consolidates workloads and removes underutilized nodes
- **Fast Scaling**: Provisions nodes in seconds, not minutes
- **Flexible Instance Selection**: Chooses from a wide range of instance types based on workload requirements

## Supported Platforms
- **AWS EKS** (Primary focus of this guide)
- **Azure AKS** (Node autoprovisioning)
- **Self-hosted Azure** (Open source provider)

## Prerequisites

### Required Tools
- **AWS CLI** - Configure with sufficient privileges for EKS cluster creation
- **Terraform** (>= 1.3) - Infrastructure as Code tool
- **kubectl** - Kubernetes command-line tool

### Verification
Verify AWS CLI authentication:
```bash
aws sts get-caller-identity
```

## Terraform Module Configuration

### Overview
The Terraform module approach provides a robust, repeatable way to deploy Karpenter with proper infrastructure as code practices.

### Module Resources
The Karpenter module creates the following AWS resources:
- IAM role for Pod Identity with scoped IAM policy for Karpenter controller
- Node IAM role for EC2 instances with Instance Profile
- Access entry for nodes to join the cluster
- SQS queue and EventBridge rules for spot termination handling
- CloudWatch event rules for capacity rebalancing

### Requirements
| Name | Version |
|------|---------|
| terraform | >= 1.3 |
| aws | >= 5.34 |

### Terraform Files
- `terraform/main.tf` - Complete EKS cluster with Karpenter
- `terraform/existing-role.tf` - Configuration using existing node IAM role
- `terraform/variables.tf` - Input variables
- `terraform/outputs.tf` - Output values
- `terraform/versions.tf` - Provider requirements
- `terraform/terraform.tfvars.example` - Example configuration

## Deployment Steps

### 1. Quick Setup (Recommended)
```bash
cd terraform
chmod +x init.sh
./init.sh
```

### 2. Manual Setup
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your desired configuration
terraform init
```

### 3. Deploy Infrastructure
```bash
terraform plan
terraform apply
```

### 3. Configure kubectl
```bash
# Get the command from Terraform output
terraform output configure_kubectl
# Run the output command, e.g.:
aws eks --region us-west-2 update-kubeconfig --name my-karpenter-cluster
```

## Testing Karpenter

### Scale Up Test
The Terraform configuration includes a test deployment. Scale it up to test Karpenter:

```bash
kubectl scale deployment inflate --replicas 5
```

### Check Deployment Status
After running the scale command, follow these steps:

```bash
# Step 1: Check deployment status
kubectl get deployment inflate
```

Expected output should show:
```
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
inflate  0/5     5            0           1m
```

```bash
# Step 2: Check pod status and node assignment
kubectl get pods -o wide
```

You should see pods in `Pending` state initially:
```
NAME                      READY   STATUS    RESTARTS   AGE   IP       NODE
inflate-xxx-xxx           0/1     Pending   0          30s   <none>   <none>
inflate-xxx-yyy           0/1     Pending   0          30s   <none>   <none>
```

```bash
# Step 3: Check current nodes
kubectl get nodes
```

```bash
# Step 4: Monitor for new nodes (Karpenter should provision them)
watch kubectl get nodes
# Or check periodically:
kubectl get nodes --watch
```

```bash
# Step 5: Check if pods are pending and why
kubectl get pods --field-selector=status.phase=Pending
kubectl describe pods | grep -A 5 "Events:"
```

```bash
# Step 6: Verify Karpenter-managed nodes (after provisioning)
kubectl get nodes -l karpenter.sh/nodepool
kubectl get nodes --show-labels | grep karpenter
```

### Monitor Karpenter Activity
Watch Karpenter provision new nodes:
```bash
# Monitor Karpenter controller logs
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter -c controller

# In another terminal, watch nodes being created
watch kubectl get nodes

# Watch NodePool status
kubectl get nodepool -w

# Check Karpenter events
kubectl get events --sort-by='.lastTimestamp' | grep -i karpenter
```

### Verify Node Provisioning
```bash
# Check node details and labels
kubectl describe nodes

# Verify node capacity and allocatable resources
kubectl top nodes

# Check which pods are running on Karpenter-provisioned nodes
kubectl get pods -o wide --all-namespaces | grep -v kube-system
```

### Scale Down Test
```bash
kubectl scale deployment inflate --replicas 0
```

Watch for node consolidation (may take 1-2 minutes):
```bash
watch kubectl get nodes
```

### Manual Node Deletion
```bash
kubectl delete node "${NODE_NAME}"
```

## Configuration Examples

### All Resources (Default)
The main configuration in `terraform/main.tf` creates all necessary resources including:
- EKS cluster with managed node groups
- Karpenter controller with IAM roles
- NodePool and EC2NodeClass configurations
- Test deployment

### Re-Use Existing Node IAM Role
See `terraform/existing-role.tf` for configuration that reuses existing nodegroup IAM role:
- Reduces resource creation
- Leverages existing permissions
- Suitable for existing clusters

## Important Notes

### DNS Policy
Karpenter uses `ClusterFirst` DNS policy by default. If managing DNS service pods with Karpenter, set `--set dnsPolicy=Default`.

### Security Tags
Karpenter uses these critical tags:
- `karpenter.sh/managed-by`
- `karpenter.sh/nodepool`
- `kubernetes.io/cluster/${CLUSTER_NAME}`

Enforce tag-based IAM policies to prevent unauthorized access.

### Windows Support
Enable Windows support in your EKS cluster for Windows workloads.

## Troubleshooting

### Provider Version Conflicts
If you encounter provider version constraint errors:

```bash
# Clear Terraform cache and reinitialize
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### If Pods Stay Pending
1. Check Karpenter logs for errors
2. Verify NodePool and EC2NodeClass configurations
3. Check AWS IAM permissions
4. Verify subnet and security group tags

### If No New Nodes Are Created
1. Check Karpenter controller is running
2. Verify NodePool limits haven't been reached
3. Check AWS service quotas
4. Verify instance types are available in the region

### Common Debugging Commands
```bash
# Check Karpenter controller status
kubectl get pods -n karpenter -l app.kubernetes.io/name=karpenter

# Check events
kubectl get events --sort-by='.lastTimestamp' | tail -20

# Check NodePool events
kubectl describe nodepool default

# Check EC2NodeClass events
kubectl describe ec2nodeclass default

# Check provider dependencies
terraform providers
```

## Cleanup
```bash
cd terraform
terraform destroy
```

## Verification
Verify chart signature (optional):
```bash
cosign verify public.ecr.aws/karpenter/karpenter:1.6.3 \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='https://github\.com/aws/karpenter-provider-aws/\.github/workflows/release\.yaml@.+' \
  --certificate-github-workflow-repository=aws/karpenter-provider-aws \
  --certificate-github-workflow-name=Release \
  --certificate-github-workflow-ref=refs/tags/v1.6.2 \
  --annotations version=1.6.3
```

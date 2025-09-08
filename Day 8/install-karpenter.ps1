# Karpenter Installation Script for Windows PowerShell
# This script installs Karpenter on an EKS cluster

param(
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,

    [Parameter(Mandatory=$true)]
    [string]$AccountId,

    [Parameter(Mandatory=$true)]
    [string]$Region = "us-east-1"
)

Write-Host "🚀 Installing Karpenter on cluster: $ClusterName" -ForegroundColor Green

# Step 1: Get cluster endpoint
Write-Host "🔍 Getting cluster endpoint..." -ForegroundColor Yellow
$clusterEndpoint = aws eks describe-cluster --name $ClusterName --query 'cluster.endpoint' --output text

if (-not $clusterEndpoint) {
    Write-Host "❌ Failed to get cluster endpoint. Please check cluster name and AWS credentials." -ForegroundColor Red
    exit 1
}

Write-Host "Cluster endpoint: $clusterEndpoint" -ForegroundColor Cyan

# Step 2: Update configuration files with actual values
Write-Host "📝 Updating configuration files..." -ForegroundColor Yellow

# Update service account
$serviceAccountContent = Get-Content "karpenter-serviceaccount.yaml" -Raw
$serviceAccountContent = $serviceAccountContent -replace "ACCOUNT_ID", $AccountId
$serviceAccountContent = $serviceAccountContent -replace "CLUSTER_NAME", $ClusterName
Set-Content "karpenter-serviceaccount.yaml" $serviceAccountContent

# Update deployment
$deploymentContent = Get-Content "karpenter-deployment.yaml" -Raw
$deploymentContent = $deploymentContent -replace "CLUSTER_NAME_PLACEHOLDER", $ClusterName
$deploymentContent = $deploymentContent -replace "CLUSTER_ENDPOINT_PLACEHOLDER", $clusterEndpoint
$deploymentContent = $deploymentContent -replace "AWS_REGION_PLACEHOLDER", $Region
Set-Content "karpenter-deployment.yaml" $deploymentContent

# Update EC2NodeClass
$nodeClassContent = Get-Content "karpenter-ec2nodeclass.yaml" -Raw
$nodeClassContent = $nodeClassContent -replace "CLUSTER_NAME_PLACEHOLDER", $ClusterName
Set-Content "karpenter-ec2nodeclass.yaml" $nodeClassContent

Write-Host "✅ Configuration files updated" -ForegroundColor Green

# Step 3: Install Karpenter CRDs
Write-Host "📦 Installing Karpenter CRDs..." -ForegroundColor Yellow
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.37.0/pkg/apis/crds/karpenter.sh_nodepools.yaml
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.37.0/pkg/apis/crds/karpenter.sh_nodeclaims.yaml
kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.37.0/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml

# Step 4: Apply Karpenter resources
Write-Host "🎛️ Deploying Karpenter resources..." -ForegroundColor Yellow

kubectl apply -f karpenter-namespace.yaml
kubectl apply -f karpenter-serviceaccount.yaml
kubectl apply -f karpenter-rbac.yaml
kubectl apply -f karpenter-service.yaml
kubectl apply -f karpenter-deployment.yaml

# Step 5: Wait for Karpenter to be ready
Write-Host "⏳ Waiting for Karpenter deployment to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=available --timeout=300s deployment/karpenter -n karpenter

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Karpenter deployment is ready" -ForegroundColor Green
} else {
    Write-Host "⚠️ Karpenter deployment might not be ready yet. Check with: kubectl get pods -n karpenter" -ForegroundColor Yellow
}

# Step 6: Apply NodeClass and NodePool
Write-Host "🖥️ Creating EC2NodeClass and NodePool..." -ForegroundColor Yellow
kubectl apply -f karpenter-ec2nodeclass.yaml
kubectl apply -f karpenter-nodepool.yaml

# Step 7: Verify installation
Write-Host "✅ Verifying Karpenter installation..." -ForegroundColor Yellow

Write-Host "Karpenter pods:" -ForegroundColor Cyan
kubectl get pods -n karpenter

Write-Host "NodePools:" -ForegroundColor Cyan
kubectl get nodepools

Write-Host "EC2NodeClasses:" -ForegroundColor Cyan
kubectl get ec2nodeclasses

Write-Host ""
Write-Host "🎉 Karpenter installation completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Yellow
Write-Host "1. Tag your subnets and security groups with 'karpenter.sh/discovery: $ClusterName'" -ForegroundColor White
Write-Host "2. Deploy test application: kubectl apply -f test-deployment.yaml" -ForegroundColor White
Write-Host "3. Monitor node provisioning: kubectl get nodes -w" -ForegroundColor White
Write-Host ""
Write-Host "🧪 Test Karpenter:" -ForegroundColor Magenta
Write-Host "kubectl apply -f test-deployment.yaml" -ForegroundColor Cyan
Write-Host "kubectl get pods -w" -ForegroundColor Cyan

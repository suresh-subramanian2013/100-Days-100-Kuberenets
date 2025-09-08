# Karpenter IAM Setup Script for Windows PowerShell
# This script creates all necessary IAM roles and policies for Karpenter

param(
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,

    [Parameter(Mandatory=$true)]
    [string]$AccountId,

    [Parameter(Mandatory=$true)]
    [string]$Region = "us-east-1"
)

Write-Host "🚀 Setting up Karpenter IAM roles for cluster: $ClusterName" -ForegroundColor Green

# Step 1: Create Karpenter Node Role
Write-Host "📝 Creating Karpenter Node Role..." -ForegroundColor Yellow

$nodeRoleTrustPolicy = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
"@

try {
    aws iam create-role --role-name "KarpenterNodeRole-$ClusterName" --assume-role-policy-document $nodeRoleTrustPolicy
    Write-Host "✅ Node role created successfully" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Node role might already exist" -ForegroundColor Yellow
}

# Step 2: Attach policies to Node Role
Write-Host "🔗 Attaching policies to Node Role..." -ForegroundColor Yellow

$nodePolicies = @(
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
)

foreach ($policy in $nodePolicies) {
    try {
        aws iam attach-role-policy --role-name "KarpenterNodeRole-$ClusterName" --policy-arn $policy
        Write-Host "✅ Attached policy: $policy" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Policy might already be attached: $policy" -ForegroundColor Yellow
    }
}

# Step 3: Create Instance Profile
Write-Host "🖥️ Creating Instance Profile..." -ForegroundColor Yellow

try {
    aws iam create-instance-profile --instance-profile-name "KarpenterNodeInstanceProfile-$ClusterName"
    Write-Host "✅ Instance profile created successfully" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Instance profile might already exist" -ForegroundColor Yellow
}

# Step 4: Add role to instance profile
try {
    aws iam add-role-to-instance-profile --instance-profile-name "KarpenterNodeInstanceProfile-$ClusterName" --role-name "KarpenterNodeRole-$ClusterName"
    Write-Host "✅ Role added to instance profile" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Role might already be in instance profile" -ForegroundColor Yellow
}

# Step 5: Get OIDC Issuer URL
Write-Host "🔍 Getting OIDC Issuer URL..." -ForegroundColor Yellow
$oidcIssuer = aws eks describe-cluster --name $ClusterName --query 'cluster.identity.oidc.issuer' --output text
$oidcId = $oidcIssuer -replace "https://oidc.eks.$Region.amazonaws.com/id/", ""

Write-Host "OIDC Issuer: $oidcIssuer" -ForegroundColor Cyan
Write-Host "OIDC ID: $oidcId" -ForegroundColor Cyan

# Step 6: Create Karpenter Controller Role
Write-Host "🎛️ Creating Karpenter Controller Role..." -ForegroundColor Yellow

$controllerRoleTrustPolicy = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::$AccountId:oidc-provider/oidc.eks.$Region.amazonaws.com/id/$oidcId"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.$Region.amazonaws.com/id/$oidcId:sub": "system:serviceaccount:karpenter:karpenter",
                    "oidc.eks.$Region.amazonaws.com/id/$oidcId:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
"@

try {
    aws iam create-role --role-name "KarpenterControllerRole-$ClusterName" --assume-role-policy-document $controllerRoleTrustPolicy
    Write-Host "✅ Controller role created successfully" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Controller role might already exist" -ForegroundColor Yellow
}

# Step 7: Create and attach Karpenter Controller Policy
Write-Host "📋 Creating Karpenter Controller Policy..." -ForegroundColor Yellow

try {
    aws iam create-policy --policy-name "KarpenterControllerPolicy-$ClusterName" --policy-document file://karpenter-controller-policy.json
    Write-Host "✅ Controller policy created successfully" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Controller policy might already exist" -ForegroundColor Yellow
}

try {
    aws iam attach-role-policy --role-name "KarpenterControllerRole-$ClusterName" --policy-arn "arn:aws:iam::$AccountId:policy/KarpenterControllerPolicy-$ClusterName"
    Write-Host "✅ Controller policy attached successfully" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Controller policy might already be attached" -ForegroundColor Yellow
}

# Step 8: Tag subnets and security groups
Write-Host "🏷️ Please tag your subnets and security groups manually:" -ForegroundColor Magenta
Write-Host "Tag Key: karpenter.sh/discovery" -ForegroundColor Cyan
Write-Host "Tag Value: $ClusterName" -ForegroundColor Cyan

Write-Host ""
Write-Host "🎉 Karpenter IAM setup completed!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Tag your subnets and security groups" -ForegroundColor White
Write-Host "2. Update karpenter-deployment.yaml with your cluster endpoint" -ForegroundColor White
Write-Host "3. Run kubectl apply commands to deploy Karpenter" -ForegroundColor White

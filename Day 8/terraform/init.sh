#!/bin/bash

# Karpenter Terraform Initialization Script
set -e

echo "=== Karpenter Terraform Setup ==="
echo

# Check prerequisites
echo "Checking prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Please install Terraform first."
    exit 1
fi

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

echo "✅ All prerequisites found"

# Check AWS authentication
echo "Checking AWS authentication..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS authentication failed. Please configure AWS CLI."
    exit 1
fi

echo "✅ AWS authentication successful"

# Create terraform.tfvars if it doesn't exist
if [ ! -f "terraform.tfvars" ]; then
    echo "Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "✅ Please edit terraform.tfvars with your desired configuration"
    echo "   Then run: terraform init && terraform plan && terraform apply"
else
    echo "✅ terraform.tfvars already exists"
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

echo
echo "=== Setup Complete ==="
echo "Next steps:"
echo "1. Edit terraform.tfvars with your configuration"
echo "2. Run: terraform plan"
echo "3. Run: terraform apply"
echo "4. Configure kubectl: aws eks --region <region> update-kubeconfig --name <cluster-name>"
echo "5. Test Karpenter: kubectl scale deployment inflate --replicas 5"

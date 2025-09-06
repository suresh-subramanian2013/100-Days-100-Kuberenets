# Day 3: Managing Multiple Kubernetes Clusters and Namespaces

Welcome to Day 3 of the 100 Days of Kubernetes journey! This day focuses on efficiently managing multiple Kubernetes clusters and namespaces using context switching and helpful tools.

## Overview

As you work with Kubernetes in real-world scenarios, you'll often need to manage multiple clusters (development, staging, production) and different namespaces within those clusters. This day covers the essential tools and techniques for seamless cluster and namespace management.

## Topics Covered

### 1. Kubernetes Context - Default Approach

Understanding how kubectl manages cluster connections:

#### What is Context?
A context in Kubernetes defines:
- **Cluster**: Which Kubernetes cluster to connect to
- **User**: Which user credentials to use
- **Namespace**: Default namespace for operations

#### Managing Contexts with kubectl

```bash
# View current context
kubectl config current-context

# List all available contexts
kubectl config get-contexts

# Switch to a different context
kubectl config use-context <context-name>

# View full kubeconfig
kubectl config view

# Set default namespace for current context
kubectl config set-context --current --namespace=<namespace-name>
```

#### Context Configuration
Contexts are stored in your kubeconfig file (usually `~/.kube/config`):

```yaml
contexts:
- context:
    cluster: my-cluster
    namespace: default
    user: my-user
  name: my-context
```

### 2. Kubectx & Kubens - Enhanced Cluster Management

Powerful open-source tools that simplify context and namespace switching:

#### Kubectx - Context Switching Made Easy

**Installation:**
```bash
# Using curl
curl -L https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubectx -o kubectx
chmod +x kubectx
sudo mv kubectx /usr/local/bin/

# Using package managers
# macOS: brew install kubectx
# Ubuntu: sudo apt install kubectx
```

**Usage:**
```bash
# List all contexts
kubectx

# Switch to a context
kubectx <context-name>

# Switch to previous context
kubectx -

# Rename a context
kubectx <new-name>=<old-name>

# Delete a context
kubectx -d <context-name>
```

#### Kubens - Namespace Switching Made Easy

**Usage:**
```bash
# List all namespaces in current context
kubens

# Switch to a namespace
kubens <namespace-name>

# Switch to previous namespace
kubens -

# Switch to default namespace
kubens default
```

## Practical Scenarios

### Multi-Cluster Management

```bash
# Development workflow
kubectx dev-cluster
kubens development
kubectl get pods

# Switch to staging
kubectx staging-cluster
kubens staging
kubectl get pods

# Production deployment
kubectx prod-cluster
kubens production
kubectl apply -f production-manifest.yaml
```

### EKS-Specific Context Management

```bash
# Add EKS cluster to kubeconfig
aws eks update-kubeconfig --region us-west-2 --name my-cluster

# List EKS contexts
kubectx | grep eks

# Switch between EKS clusters
kubectx arn:aws:eks:us-west-2:123456789:cluster/dev-cluster
kubectx arn:aws:eks:us-west-2:123456789:cluster/prod-cluster
```

## Best Practices

### 1. Context Naming Convention
- Use descriptive names: `dev-us-west-2`, `prod-eu-central-1`
- Include environment and region information
- Keep names short but meaningful

### 2. Safety Measures
```bash
# Always verify current context before operations
kubectl config current-context

# Use namespace-specific commands when needed
kubectl get pods -n specific-namespace

# Set up aliases for frequently used contexts
alias k8s-dev='kubectx dev-cluster && kubens development'
alias k8s-prod='kubectx prod-cluster && kubens production'
```

### 3. Visual Indicators
- Use shell prompts that show current context/namespace
- Consider tools like `kube-ps1` for bash/zsh prompts
- Use different terminal colors for different environments

## Troubleshooting

### Common Issues
```bash
# Context not found
kubectx
kubectl config get-contexts

# Permission denied
kubectl auth can-i get pods
kubectl auth can-i get pods --as=system:serviceaccount:default:default

# Wrong namespace
kubens
kubectl get pods -A  # List pods in all namespaces
```

## Advanced Tips

### 1. Kubeconfig Management
```bash
# Merge multiple kubeconfig files
KUBECONFIG=~/.kube/config:~/.kube/config-cluster2 kubectl config view --merge --flatten > ~/.kube/merged-config

# Use different kubeconfig files
export KUBECONFIG=~/.kube/special-config
```

### 2. Automation Scripts
```bash
#!/bin/bash
# Quick cluster health check script
for context in $(kubectx); do
    echo "Checking $context..."
    kubectx $context
    kubectl get nodes --no-headers | wc -l
done
```

## Key Takeaways

- Context switching is essential for multi-cluster management
- kubectx and kubens significantly improve productivity
- Always verify your current context before running commands
- Use descriptive naming conventions for contexts
- Implement safety measures to prevent accidental operations on wrong clusters

## Next Steps

With efficient cluster and namespace management skills, you're ready to proceed to Day 4, which covers Quality of Service classes in Kubernetes.
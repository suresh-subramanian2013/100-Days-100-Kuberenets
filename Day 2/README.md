# Day 2: Kubernetes Architecture and Pod Troubleshooting

Welcome to Day 2 of the 100 Days of Kubernetes journey! This day focuses on understanding Kubernetes architecture and common pod troubleshooting scenarios.

## Overview

Understanding Kubernetes architecture is fundamental to working effectively with the platform. This day covers the core components and demonstrates common pod issues you'll encounter in real-world scenarios.

## Topics Covered

### 1. Kubernetes Architecture

Learn about the key components that make up a Kubernetes cluster:

#### Control Plane Components
- **API Server**: The central management entity that receives all REST requests
- **etcd**: Distributed key-value store for cluster data
- **Controller Manager**: Runs controller processes
- **Scheduler**: Assigns pods to nodes based on resource requirements

#### Node Components
- **kubelet**: Agent that runs on each node and manages pods
- **kube-proxy**: Network proxy that maintains network rules
- **Container Runtime**: Software responsible for running containers (Docker, containerd, etc.)

### 2. Pod Creation Process

Understanding the lifecycle of pod creation:

1. **kubectl** sends request to **API Server**
2. **API Server** validates and stores the request in **etcd**
3. **Scheduler** watches for unscheduled pods and assigns them to nodes
4. **kubelet** on the target node pulls the image and creates the pod
5. **Container Runtime** starts the containers
6. **kubelet** reports pod status back to **API Server**

### 3. ImagePullBackOff - Troubleshooting

Common scenarios and solutions for ImagePullBackOff errors:

#### Causes:
- Image name or tag is incorrect
- Image doesn't exist in the registry
- Authentication issues with private registries
- Network connectivity problems

#### Troubleshooting Steps:
```bash
# Check pod status
kubectl get pods

# Describe pod for detailed error information
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Verify image exists
docker pull <image-name>
```

### 4. CrashLoopBackOff - Troubleshooting

Understanding and resolving CrashLoopBackOff issues:

#### Causes:
- Application crashes immediately after startup
- Incorrect command or arguments
- Missing environment variables or configuration
- Resource constraints
- Health check failures

#### Troubleshooting Steps:
```bash
# Check pod logs
kubectl logs <pod-name>

# Check previous container logs
kubectl logs <pod-name> --previous

# Describe pod for resource and event information
kubectl describe pod <pod-name>

# Check resource limits and requests
kubectl get pod <pod-name> -o yaml
```

## Practical Exercises

1. **Architecture Review**: Draw or identify the components in your cluster
2. **Pod Creation**: Create a simple pod and trace its creation process
3. **ImagePullBackOff Demo**: Intentionally create a pod with wrong image name
4. **CrashLoopBackOff Demo**: Create a pod that exits immediately

## Common Commands

```bash
# Get cluster information
kubectl cluster-info

# List all nodes
kubectl get nodes

# Check component status
kubectl get componentstatuses

# Monitor pod creation
kubectl get pods -w

# Get detailed pod information
kubectl describe pod <pod-name>

# Check pod logs
kubectl logs <pod-name> -f
```

## Key Takeaways

- Kubernetes follows a declarative model where you describe desired state
- The control plane continuously works to maintain the desired state
- Most pod issues can be diagnosed using `kubectl describe` and `kubectl logs`
- Understanding the pod lifecycle helps in effective troubleshooting
- Always check events and logs when pods fail to start

## Next Steps

With a solid understanding of Kubernetes architecture and basic troubleshooting, you're ready to move on to Day 3, which covers managing multiple clusters and namespaces.
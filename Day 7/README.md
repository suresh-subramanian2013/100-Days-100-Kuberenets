# Kubernetes Demo App with PodDisruptionBudgets

This repository contains Kubernetes manifests for a demo application with PodDisruptionBudget configurations to ensure high availability during voluntary disruptions.

## Files

- `deployment.yaml` - Sample deployment running nginx with 3 replicas
- `pod-disruption-budgets.yaml` - Two PDB configurations demonstrating different approaches

## Deployment

The demo app deployment creates:
- 3 nginx pods (version 1.25)
- Pods labeled with `app: demo`
- Container listening on port 80

## PodDisruptionBudgets

### 1. minAvailable PDB
- **Name**: `demo-app-pdb-min`
- **Policy**: Ensures at least 2 pods are always running
- **Use case**: Guarantees minimum service capacity during disruptions

### 2. maxUnavailable PDB
- **Name**: `demo-app-pdb-max`
- **Policy**: Allows maximum 1 pod to be unavailable
- **Use case**: Limits disruption impact while allowing maintenance

## Usage

Deploy the resources:

```bash
kubectl apply -f deployment.yaml
kubectl apply -f pod-disruption-budgets.yaml
```

Verify PodDisruptionBudgets:

```bash
kubectl get pdb
kubectl describe pdb demo-app-pdb-min
kubectl describe pdb demo-app-pdb-max
```

## Notes

- Both PDBs target the same deployment using `app: demo` selector
- Only one PDB should be used at a time for the same set of pods
- PDBs only apply to voluntary disruptions (node drains, upgrades, etc.)
- They don't protect against involuntary disruptions (hardware failures, etc.)



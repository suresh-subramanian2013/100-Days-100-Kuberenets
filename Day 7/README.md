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


## Hands-on Steps for this PDB

Let's go step by step for the case where a node has 2 pods and you try to drain it.

### Setup
- **node-01** → 2 pods
- **node-02** → 1 pod
- **Total** = 3 pods

### 🔹 Case 1: minAvailable: 2
**Rule**: At least 2 must always remain.

If you drain node-01 → 2 pods evicted → only 1 left.
- ✅ **Allowed?** No → because 1 < 2.
- ❌ **Drain blocked**.

### 🔹 Case 2: maxUnavailable: 1
**Rule**: At most 1 pod can be unavailable.

If you drain node-01 → 2 pods evicted at once.
That's 2 unavailable.
- ✅ **Allowed?** No → because 2 > 1.
- ❌ **Drain blocked**.

### ✅ Summary for your demo
- **Drain node-02 (1 pod)** → ✅ Works in both cases.
- **Drain node-01 (2 pods)** → ❌ Blocked in both cases (whether you use minAvailable=2 or maxUnavailable=1).

That's the behavior you should highlight when showing a PDB demo.
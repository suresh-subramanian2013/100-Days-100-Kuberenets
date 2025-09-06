# Kubernetes Quality of Service (QoS) Classes

This repository demonstrates Kubernetes Quality of Service (QoS) classes through different pod configurations. QoS classes determine pod scheduling priority and eviction behavior during resource pressure.

## Files

- `qos.yaml` - Pod examples demonstrating all three QoS classes

## Kubernetes QoS Classes

Kubernetes automatically assigns QoS classes based on resource requests and limits:

### 1. Guaranteed QoS
- **Requirements**: CPU and memory requests = limits for all containers
- **Priority**: Highest (last to be evicted)
- **Use case**: Critical applications requiring predictable resources

**Example**: `guaranteed-pod`
```yaml
resources:
  requests:
    memory: 128Mi
    cpu: 500m
  limits:
    memory: 128Mi  # Same as request
    cpu: 500m      # Same as request
```

### 2. Burstable QoS
- **Requirements**: At least one container has CPU or memory request/limit (but not equal)
- **Priority**: Medium (evicted after BestEffort, before Guaranteed)
- **Use case**: Applications with variable resource needs

**Examples**: 
- `burstable-pod` - Has both requests and limits (limits > requests)
- `burstable-no-limit-pod` - Has requests but no limits

### 3. BestEffort QoS
- **Requirements**: No CPU or memory requests/limits specified
- **Priority**: Lowest (first to be evicted)
- **Use case**: Non-critical workloads, batch jobs

**Example**: `best-effort-pod`
```yaml
# No resources section = BestEffort
```

## Usage

Deploy all QoS examples:

```bash
kubectl apply -f qos.yaml
```

Verify QoS assignments:

```bash
kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
kubectl describe pod guaranteed-pod | grep "QoS Class"
kubectl describe pod burstable-pod | grep "QoS Class"
kubectl describe pod best-effort-pod | grep "QoS Class"
```

Check resource usage:

```bash
kubectl top pods
```

## QoS Behavior During Resource Pressure

When nodes experience resource pressure, Kubernetes evicts pods in this order:

1. **BestEffort pods** - Evicted first
2. **Burstable pods** - Evicted based on resource usage vs requests
3. **Guaranteed pods** - Evicted last (only if they exceed limits)

## Best Practices

- Use **Guaranteed** for critical system components and databases
- Use **Burstable** for most application workloads
- Use **BestEffort** for batch jobs and non-critical tasks
- Always set resource requests to help scheduler make informed decisions
- Set appropriate limits to prevent resource hogging

## Cleanup

Remove all test pods:

```bash
kubectl delete -f qos.yaml
```
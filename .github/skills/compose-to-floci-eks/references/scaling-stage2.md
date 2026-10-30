# Stage-2 scaling scaffolding & teaching notes

Extras to include when the exercise moves from "run it on Kubernetes" to
"scale its components." Add these as commented, explained scaffolding so
students turn them on deliberately.

## 1. Replicas (manual scaling)

In a Deployment:

```yaml
spec:
  replicas: 1   # Stage-2: raise this (e.g. 3) to run multiple app pods
```

Teaching points:
- The Service load-balances across all Ready pods automatically.
- Try `kubectl scale deployment/<name> --replicas=3 -n <ns>` and watch traffic
  spread. Contrast declarative (`replicas:` in YAML) vs. imperative (`scale`).
- **Stateless vs. stateful:** the app tier scales horizontally; the database
  generally does NOT just by bumping `replicas`. Great discussion prompt.
- Floci runs a single k3s node, so all replicas land on one "machine". On real
  EKS, replicas spread across node-group instances — a good lead-in to node
  scaling (Cluster Autoscaler / Karpenter).

## 2. Resource requests and limits

```yaml
resources:
  requests:        # what the scheduler reserves
    cpu: "100m"
    memory: "128Mi"
  limits:          # hard ceiling before throttling/OOM-kill
    cpu: "500m"
    memory: "256Mi"
```

Teaching points:
- `requests` drive scheduling and are the denominator for autoscaling.
- Without `requests`, a HorizontalPodAutoscaler on CPU has nothing to compute
  utilization against.
- Keep totals modest: everything shares the memory you gave Docker Desktop.

## 3. HorizontalPodAutoscaler (automatic scaling)

```yaml
# Requires a working metrics API. k3s normally bundles metrics-server; check:
#   kubectl get deployment metrics-server -n kube-system
#   kubectl top pods -n <ns>
# If `kubectl top` errors, install metrics-server:
#   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# (On real EKS you install metrics-server yourself or via the EKS add-on.)
#
# apiVersion: autoscaling/v2
# kind: HorizontalPodAutoscaler
# metadata:
#   name: app-hpa
#   namespace: <ns>
# spec:
#   scaleTargetRef:
#     apiVersion: apps/v1
#     kind: Deployment
#     name: <app-deployment>
#   minReplicas: 1
#   maxReplicas: 5
#   metrics:
#     - type: Resource
#       resource:
#         name: cpu
#         target:
#           type: Utilization
#           averageUtilization: 50
```

Teaching points:
- Confirm `kubectl top pods` works first, or the HPA reports `<unknown>` targets.
- Generate load (e.g. a simple `hey`/`ab`/loop through `port-forward`, or a
  busybox pod hitting the Service) and watch `kubectl get hpa -n <ns> -w`
  scale pods up, then back down.
- Connect back to the requests/limits: autoscaling is meaningless without them.

## Suggested student exercises

1. Scale the app to 3 replicas manually; confirm the Service balances requests.
2. Add requests/limits; observe scheduling behavior.
3. Verify metrics, add the HPA; drive load and observe autoscaling.
4. Discuss why the database tier needs a different strategy (StatefulSet,
   read replicas, connection pooling, or a managed service like RDS) — a lead-in
   to later material.

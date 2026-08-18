# Compose → Kubernetes mapping reference

A translation guide from Docker Compose concepts to Kubernetes resources, for
students converting a stack to run on minikube. The right column is what to
generate for each Compose construct.

| Docker Compose | Kubernetes equivalent | Notes for students |
|----------------|-----------------------|--------------------|
| `services:` (one entry) | A `Deployment` **+** a `Service` | The Deployment runs the pod(s); the Service gives them a stable in-cluster DNS name. |
| `image: foo:bar` | `spec.containers[].image: foo:bar` | If pulled from a registry, default pull policy is fine. |
| `build:` (local image) | `image: <name>:<tag>` + `imagePullPolicy: Never` | Must `eval $(minikube docker-env)` and build *before* applying, or the pod gets `ErrImageNeverPull`. |
| `ports: ["80:3000"]` | Service `port: 80`, `targetPort: 3000` | Compose publishes to the host; in K8s the Service maps a cluster port to the container port. External access uses `minikube service` or `port-forward`. |
| `environment:` (non-secret) | `ConfigMap` + `envFrom`/`valueFrom` | Keep configuration separate from the image. |
| `environment:` (passwords/tokens) | `Secret` | Teachable moment: Secrets are base64-encoded and access-controlled, not encrypted by default, but are the correct place for credentials. |
| `depends_on: condition: service_healthy` | `readinessProbe` on the dependency + ret/backoff in the client | K8s has no direct `depends_on`; readiness gating + the app's own retry (e.g. `wait-port`) achieve ordering. |
| `healthcheck:` | `readinessProbe` / `livenessProbe` | Readiness = "route traffic yet?"; liveness = "restart if wedged?". |
| `volumes:` (named) | `PersistentVolumeClaim` + `volumeMounts` | On minikube the default StorageClass provisions local storage. |
| top-level `volumes:` | `PersistentVolumeClaim` (per claim) | Data persists across pod restarts until the PVC is deleted. |
| `labels` (Traefik routing) | `Service` type + optional `Ingress` | For a bundled single-service app, a `LoadBalancer`/`NodePort` Service is enough; multi-service routing → Ingress. |
| multiple replicas (implicit 1) | `spec.replicas: N` | The core lever for the stage-2 scaling assignment. |
| `networks:` | Cluster networking (automatic) | Pods reach each other by Service DNS name; usually no explicit config needed. |

## Naming conventions to teach

- Service DNS name = the Service `metadata.name` (e.g. an app reaches the DB at
  `mysql-service`). Set the app's `DB_HOST` env to that name.
- Keep everything in one `Namespace` so `kubectl delete namespace <ns>` cleans
  up the whole exercise.

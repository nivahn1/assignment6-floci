# Compose → Kubernetes mapping reference (EKS on Floci)

A translation guide from Docker Compose concepts to Kubernetes resources, for
students converting a stack to run on an emulated EKS cluster in Floci. The
right column is what to generate for each Compose construct.

| Docker Compose | Kubernetes equivalent | Notes for students |
|----------------|-----------------------|--------------------|
| `services:` (one entry) | A `Deployment` **+** a `Service` | The Deployment runs the pod(s); the Service gives them a stable in-cluster DNS name. |
| `image: foo:bar` | `spec.containers[].image: foo:bar` | Public registry images (e.g. `mysql:9.3`) pull normally; the default pull policy is fine. |
| `build:` (local image) | `image: 000000000000.dkr.ecr.us-east-1.localhost:4566/<repo>:<tag>` + `imagePullPolicy: IfNotPresent` | Build, tag with the ECR URI, and `docker push` *before* applying, or the pod gets `ImagePullBackOff`. On real AWS the only change is the account ID and an `amazonaws.com` host. |
| `ports: ["80:3000"]` | Service `port: 80`, `targetPort: 3000` | Compose publishes to the host; in K8s the Service maps a cluster port to the container port. Use `ClusterIP` + `kubectl port-forward` on Floci; on real EKS you'd use `type: LoadBalancer`. |
| `environment:` (non-secret) | `ConfigMap` + `envFrom`/`valueFrom` | Keep configuration separate from the image. |
| `environment:` (passwords/tokens) | `Secret` | Teachable moment: Secrets are base64-encoded and access-controlled, not encrypted by default, but are the correct place for credentials. (Real EKS can add KMS envelope encryption.) |
| `depends_on: condition: service_healthy` | `readinessProbe` on the dependency + retry/backoff in the client | K8s has no direct `depends_on`; readiness gating + the app's own retry (e.g. `wait-port`) achieve ordering. |
| `healthcheck:` | `readinessProbe` / `livenessProbe` | Readiness = "route traffic yet?"; liveness = "restart if wedged?". |
| `volumes:` (named) | `PersistentVolumeClaim` + `volumeMounts` | Floci (like real EKS) has no default StorageClass unless `FLOCI_SERVICES_EKS_DEFAULT_STORAGE_CLASS=true`; then k3s `local-path` provisions storage. On real EKS this is the EBS CSI driver. |
| top-level `volumes:` | `PersistentVolumeClaim` (per claim) | Data persists across pod restarts until the PVC (or the cluster) is deleted. |
| `labels` (Traefik routing) | `Service` type + optional `Ingress` | For a bundled single-service app, one Service is enough; multi-service routing → Ingress (on AWS, the AWS Load Balancer Controller). |
| multiple replicas (implicit 1) | `spec.replicas: N` | The core lever for the stage-2 scaling assignment. |
| `networks:` | Cluster networking (automatic) | Pods reach each other by Service DNS name; usually no explicit config needed. |

## AWS concepts the student meets along the way

| Step | Floci (local) | Real AWS (later) |
|------|---------------|------------------|
| Registry | `000000000000.dkr.ecr.us-east-1.localhost:4566` | `<account>.dkr.ecr.<region>.amazonaws.com` |
| Cluster | `aws eks create-cluster` → one k3s container | Managed control plane + node groups/Fargate |
| kubectl login | `aws eks update-kubeconfig` + IAM user key | Same command, real IAM identity |
| Storage | k3s `local-path` (opt-in) | EBS CSI driver + `gp3` StorageClass |
| External access | `kubectl port-forward` | `LoadBalancer` Service / Ingress |

## Naming conventions to teach

- Service DNS name = the Service `metadata.name` (e.g. the app reaches the DB
  at `mysql`). Set the app's DB host env var to that name.
- Keep everything in one `Namespace` so `kubectl delete namespace <ns>` cleans
  up the whole exercise.
- Use explicit image tags (`v1`, `v2`) so a new push actually rolls out and
  `IfNotPresent` doesn't keep serving a stale image.

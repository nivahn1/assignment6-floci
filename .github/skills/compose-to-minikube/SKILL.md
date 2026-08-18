---
name: compose-to-minikube
description: 'Convert an arbitrary Dockerfile + Docker Compose stack into Kubernetes manifests and deploy them to a local minikube cluster. Use when a student or instructor wants to take a docker-compose.yml / compose.yaml (and its Dockerfile) and run it on Kubernetes locally with minikube and kubectl — including generating Deployments, Services, ConfigMaps, Secrets, and PersistentVolumeClaims, building images into minikube, applying manifests, verifying pods, accessing the app, and cleaning up. Teaching-oriented: explains each step for a software-engineering course on scalable cloud architecture. DO NOT use for cloud/managed Kubernetes (EKS/GKE/AKS) or production CI/CD.'
argument-hint: 'path to the compose file (e.g., compose.prod.yaml)'
---

# Compose → minikube (local Kubernetes)

A teaching-oriented workflow for converting a Docker Compose stack into
Kubernetes manifests and running it on a local **minikube** cluster. Designed
for a software-engineering course introducing scalable cloud architecture.
This is a **stage-2** activity: students already know Docker/Compose; here they
meet Kubernetes locally before a later component-scaling assignment.

## When to use

- A student has a `Dockerfile` + `compose*.yaml` and wants it running on minikube.
- Converting Compose services → Kubernetes Deployments/Services/ConfigMaps/PVCs.
- Diagnosing local Kubernetes/minikube issues (see the troubleshooting reference).
- Setting up scaffolding for a later scaling exercise (replicas, HPA).

## Teaching stance (important)

- **Generate manifests, then guide the student to run the commands themselves.**
  Do not auto-run the full deploy sequence. Show each command, explain what it
  does and why, and let the student execute it. This builds muscle memory.
- **Explain, don't just emit.** For each resource kind, state the Compose
  concept it replaces (see the mapping reference).
- **Require explicit confirmation before any destructive command**
  (`kubectl delete`, `minikube delete`, `docker system prune`, `down -v`).
  Never run these on the student's behalf without a clear yes.

## Procedure

1. **Read the inputs.** Parse the target `compose*.yaml` and the `Dockerfile`.
   Identify services, build targets/stages, images, ports, environment
   variables, volumes, `depends_on`, and healthchecks.

2. **Plan the mapping.** For each Compose service, decide the Kubernetes
   resources needed. Use the translation table in
   [compose-to-k8s mapping](./references/compose-to-k8s-mapping.md).

3. **Generate manifests** into a `k8s/` directory. Prefer one file per concern
   (namespace, configmap, secret, pvc, one file per workload+service). Include a
   short header comment in each file explaining the resource for students.
   - Use a dedicated `Namespace`.
   - Put non-secret env in a `ConfigMap`; put passwords/tokens in a `Secret`
     (explain the difference — this is a teachable moment).
   - For stateful services (databases), add a `PersistentVolumeClaim`.
   - For locally built images, set `image: <name>:<tag>` and
     `imagePullPolicy: Never` so minikube uses the local build.
   - Add `readinessProbe`/`livenessProbe` derived from Compose healthchecks.

4. **Build the image into minikube.** Guide the student to point Docker at
   minikube's daemon *before* building, so the image lands inside the cluster.
   The `docker-env` line is shell-specific — give students the variant for
   their OS/shell:

   macOS / Linux (bash or zsh):
   ```bash
   minikube start
   eval $(minikube docker-env)
   docker build -f Dockerfile --target <final-stage> -t <name>:<tag> .
   ```

   Windows PowerShell:
   ```powershell
   minikube start
   & minikube -p minikube docker-env --shell powershell | Invoke-Expression
   docker build -f Dockerfile --target <final-stage> -t <name>:<tag> .
   ```

   Windows cmd.exe:
   ```bat
   minikube start
   @FOR /f "tokens=*" %i IN ('minikube -p minikube docker-env --shell cmd') DO @%i
   docker build -f Dockerfile --target <final-stage> -t <name>:<tag> .
   ```

   Note: `minikube docker-env` only affects the current shell. If a student
   opens a new terminal, they must re-run the variant for their shell before
   building. On all platforms, `kubectl` and `minikube` subcommands are
   identical; only the `docker-env` "eval" step differs.

5. **Apply and verify.** Guide the student through:
   ```bash
   kubectl apply -f k8s/
   kubectl get pods -n <namespace> -w   # Ctrl-C to stop the watch
   ```

6. **Access the app.** `minikube service <svc> -n <namespace>` or
   `kubectl port-forward -n <namespace> service/<svc> 8080:80`.

7. **Clean up (confirm first).** `kubectl delete -f k8s/` or
   `kubectl delete namespace <namespace>`, then `minikube stop`.

## Stage-2 scaling scaffolding

When preparing for the scaling assignment, include the extras described in
[scaling-stage2](./references/scaling-stage2.md): `replicas`, resource
`requests`/`limits`, and a commented HorizontalPodAutoscaler with teaching notes.

## Troubleshooting

Common local-Kubernetes failures and their root causes (e.g. `localhost:8080
connection refused` = no cluster/context, `ErrImageNeverPull` = image not built
into minikube) are collected in
[troubleshooting](./references/troubleshooting.md).

## Guardrails

- Read-only inspection (`kubectl get/describe/logs`, `minikube status`) is always safe.
- **Never** run destructive commands without explicit student confirmation.
- Prefer `--dry-run=client -o yaml` to preview generated resources.

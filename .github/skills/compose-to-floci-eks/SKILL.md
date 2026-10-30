---
name: compose-to-floci-eks
description: 'Convert an arbitrary Dockerfile + Docker Compose stack into Kubernetes manifests and deploy them to an emulated Amazon EKS cluster running in Floci (a local AWS emulator on localhost:4566). Use when a student or instructor wants to take a docker-compose.yml / compose.yaml (and its Dockerfile) and run it on Kubernetes locally with Floci, the AWS CLI and kubectl — including generating Deployments, Services, ConfigMaps, Secrets, and PersistentVolumeClaims, pushing images to emulated ECR, creating an emulated EKS cluster, connecting kubectl with IAM credentials, verifying pods, accessing the app, and cleaning up. Teaching-oriented: explains each step for a software-engineering course on scalable cloud architecture. DO NOT use for real AWS accounts, real managed Kubernetes (EKS/GKE/AKS), or production CI/CD.'
argument-hint: 'path to the compose file (e.g., compose.prod.yaml)'
---

# Compose → EKS on Floci (emulated AWS, local Kubernetes)

A teaching-oriented workflow for converting a Docker Compose stack into
Kubernetes manifests and running it on an **emulated EKS cluster** provided by
**Floci**. Floci serves AWS APIs on `http://localhost:4566`; its EKS service
starts a real k3s cluster in Docker and its ECR service is a real registry.
Designed for a software-engineering course introducing scalable cloud
architecture. This is a **stage-2** activity: students already know
Docker/Compose; here they meet Kubernetes *and* the AWS workflow locally,
before a later component-scaling assignment and a real-cloud deployment.

## When to use

- A student has a `Dockerfile` + `compose*.yaml` and wants it running on EKS in Floci.
- Converting Compose services → Kubernetes Deployments/Services/ConfigMaps/PVCs.
- Diagnosing Floci/EKS/ECR/kubectl issues (see the troubleshooting reference).
- Setting up scaffolding for a later scaling exercise (replicas, HPA).

## Teaching stance (important)

- **Generate manifests, then guide the student to run the commands themselves.**
  Do not auto-run the full deploy sequence. Show each command, explain what it
  does and why, and let the student execute it. This builds muscle memory.
- **Explain, don't just emit.** For each resource kind, state the Compose
  concept it replaces (see the mapping reference). For each AWS step, say what
  changes on real AWS (account ID, `amazonaws.com` hosts, real IAM).
- **Floci only.** Every `aws` command must run with
  `AWS_ENDPOINT_URL=http://localhost:4566`. Confirm before suggesting AWS
  commands; never touch real AWS credentials.
- **Require explicit confirmation before any destructive command**
  (`kubectl delete`, `aws eks delete-cluster`, `aws ecr delete-repository`,
  `docker compose ... down`, `docker system prune`, `down -v`). Never run these
  on the student's behalf without a clear yes.

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
   - For locally built images, set
     `image: 000000000000.dkr.ecr.us-east-1.localhost:4566/<repo>:<tag>` and
     `imagePullPolicy: IfNotPresent`. Use explicit tags (`v1`, `v2`), not
     `latest`.
   - Use `ClusterIP` Services and reach them with `kubectl port-forward`
     (the k3s node doesn't publish NodePorts to the host).
   - Add `readinessProbe`/`livenessProbe` derived from Compose healthchecks.

4. **Point the shell at Floci and start it.** Env vars are shell-specific —
   give students the variant for their OS/shell:

   macOS / Linux (bash or zsh):
   First start Floci (no AWS variables needed for this):
   ```bash
   docker compose -f compose.floci.yaml up -d
   ```
   `compose.floci.yaml` must mount `/var/run/docker.sock`, publish only
   `4566:4566`, set `FLOCI_SERVICES_DOCKER_NETWORK` to its (fixed-name)
   network, and set `FLOCI_SERVICES_EKS_DEFAULT_STORAGE_CLASS: "true"`.

   Then point the shell at Floci and log in as the IAM user, using the repo's
   helper script. It must be **sourced** so the variables stay in the shell:

   macOS / Linux / Git Bash / WSL (bash or zsh):
   ```bash
   source scripts/floci-env.sh
   ```

   Windows PowerShell (note the leading dot):
   ```powershell
   . ./scripts/floci-env.ps1
   ```

   The script sets `AWS_ENDPOINT_URL=http://localhost:4566` and the region,
   uses Floci's bootstrap login (`test`/`test`) to create an IAM user
   `student` with an access key, switches the shell to that key, and caches it
   in `.floci/` (git-ignored) so new terminals reuse it. It re-creates the user
   if Floci was restarted. Explain *why* it exists: Floci rejects `test`/`test`
   for EKS auth because it would grant cluster-admin. Students re-run it in
   every new terminal. Expect: `floci-env: ready ... as arn:aws:iam::000000000000:user/student`.

   If a student wants to see the manual steps, they are:
   `aws iam create-user --user-name student` →
   `aws iam create-access-key --user-name student` → export the two values as
   `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` → `aws sts get-caller-identity`.

5. **Build and push the image to ECR.**
   ```bash
   aws ecr create-repository --repository-name <repo>   # "AlreadyExists" is fine
   aws ecr get-login-password | docker login --username AWS --password-stdin \
     000000000000.dkr.ecr.us-east-1.localhost:4566
   docker build -f Dockerfile --target <final-stage> \
     -t 000000000000.dkr.ecr.us-east-1.localhost:4566/<repo>:<tag> .
   docker push 000000000000.dkr.ecr.us-east-1.localhost:4566/<repo>:<tag>
   aws ecr list-images --repository-name <repo>
   ```
   Floci gives each EKS cluster a registry mirror for its ECR hostnames, so the
   same image reference works for the host push and the in-cluster pull.
   `docker build` needs the repo root (where the `Dockerfile` is) as its
   working directory.

6. **Check the identity before touching EKS.** `aws sts get-caller-identity`
   must show `user/student` in account `000000000000`. If it shows `root`
   or the endpoint is unset, re-source the env script.

7. **Create the cluster and connect kubectl.** In zsh (macOS default), the
   `--resources-vpc-config` value MUST be quoted; unquoted `[]` is a glob and
   fails with `zsh: no matches found`.
   ```bash
   aws eks create-cluster --name <cluster> \
     --role-arn arn:aws:iam::000000000000:role/eks-role \
     --resources-vpc-config 'subnetIds=[],securityGroupIds=[]'
   aws eks wait cluster-active --name <cluster>
   aws eks update-kubeconfig --name <cluster>
   kubectl get nodes
   ```
   The kubeconfig uses `aws eks get-token`, so every shell running `kubectl`
   needs the env script sourced.

8. **Apply and verify.**
   ```bash
   kubectl apply -f k8s/
   kubectl get pods -n <namespace> -w   # Ctrl-C to stop the watch
   kubectl get pvc -n <namespace>       # should be Bound
   ```

9. **Access the app.**
   `kubectl port-forward -n <namespace> service/<svc> 8080:80`, then open
   `http://localhost:8080`.

   **Capture evidence.** `scripts/floci-status.sh | tee floci-evidence.txt`
   (PowerShell: `./scripts/floci-status.ps1 *>&1 | Tee-Object floci-evidence.txt`)
   is a read-only snapshot of identity, ECR, cluster, pods and an HTTP check.
   It is also the fastest first diagnostic when something is wrong — you may
   run it yourself at any time.

10. **Clean up (confirm first).** `kubectl delete -f k8s/` →
    `aws eks delete-cluster --name <cluster>` →
    `docker compose -f compose.floci.yaml down`. Delete the cluster before
    stopping Floci so no `floci-eks-<cluster>` container is left behind.

## Stage-2 scaling scaffolding

When preparing for the scaling assignment, include the extras described in
[scaling-stage2](./references/scaling-stage2.md): `replicas`, resource
`requests`/`limits`, and a commented HorizontalPodAutoscaler with teaching notes.

## Troubleshooting

Common failures and their root causes (e.g. `Unauthorized` = still using
`test`/`test`; `ImagePullBackOff` = tag not in ECR; PVC `Pending` = no
StorageClass) are collected in
[troubleshooting](./references/troubleshooting.md).

## Guardrails

- Read-only inspection (`kubectl get/describe/logs`, `aws ... describe/list`,
  `aws sts get-caller-identity`, `docker ps`, `scripts/floci-status.sh`) is
  always safe.
- **Never** run destructive commands without explicit student confirmation.
- **Never** run `aws` commands without the Floci endpoint set.
- Prefer `--dry-run=client -o yaml` to preview generated resources.

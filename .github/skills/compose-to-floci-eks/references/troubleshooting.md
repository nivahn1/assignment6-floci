# Floci / EKS / kubectl troubleshooting

Common failures students hit, with the underlying cause and the fix. Diagnose
before changing manifests — most issues are environment, credential, or
cluster-state problems, not YAML.

## `aws` command hangs, asks for credentials, or mentions `amazonaws.com`

- **Cause:** `AWS_ENDPOINT_URL` isn't set in this shell, so the CLI is trying
  to reach **real AWS**.
- **Diagnose:**
  ```bash
  echo $AWS_ENDPOINT_URL          # PowerShell: $env:AWS_ENDPOINT_URL
  docker ps --filter name=floci
  ```
- **Fix:** make sure the `floci` container is running, then
  `source scripts/floci-env.sh`. Stop and fix this before any other `aws` step.

## First step for any problem

Run the read-only snapshot, which shows identity, ECR, cluster, pods and
whether the app answers:
```bash
scripts/floci-status.sh        # PowerShell: ./scripts/floci-status.ps1
```

## `zsh: no matches found: subnetIds=[],securityGroupIds=[]`

- **Cause:** zsh (the macOS default shell) treats `[]` as a filename pattern.
- **Fix:** quote it: `--resources-vpc-config 'subnetIds=[],securityGroupIds=[]'`.

## `ls: Dockerfile: No such file or directory` / `kubectl apply -f k8s/` finds nothing

- **Cause:** the terminal isn't in the repository root.
- **Fix:** `cd` to the clone (the folder with `Dockerfile`, `compose.floci.yaml`
  and `k8s/`). Floci and the cluster keep running; re-source
  `scripts/floci-env.sh` only if this is a new terminal.

## `RepositoryAlreadyExistsException` on `aws ecr create-repository`

- **Not an error.** The repository is already there from an earlier run; skip to
  `docker login`.

## `kubectl` → `Unauthorized` / `You must be logged in to the server`

- **Cause:** the shell is still using `test`/`test` (or `floci`/`floci`). Floci
  deliberately rejects those for EKS auth because they'd grant cluster-admin.
  Less often: `AWS_ENDPOINT_URL` is missing in the shell running `kubectl`
  (the kubeconfig calls `aws eks get-token`).
- **Diagnose:** `aws sts get-caller-identity` — it should show `user/student`
  in account `000000000000`.
- **Fix:** `source scripts/floci-env.sh` in this terminal (it creates or reuses
  the IAM user's key), then retry. If the cluster was recreated, also re-run
  `aws eks update-kubeconfig --name <cluster>`.

## `dial tcp ... connection refused` on `kubectl apply`

- **Cause:** no reachable API server — the cluster isn't ACTIVE, the k3s
  container stopped, or the kubeconfig context points at an old cluster.
  If it's `localhost:8080`, there's no context at all.
- **Diagnose:**
  ```bash
  aws eks describe-cluster --name <cluster> --query cluster.status
  docker ps -a --filter name=floci-eks
  kubectl config current-context
  ```
- **Fix:** wait for `ACTIVE` (`aws eks wait cluster-active`), then
  `aws eks update-kubeconfig --name <cluster>`. If Floci was restarted, the
  in-memory account is gone — re-run the runbook.
- **Note:** `--validate=false` does NOT help — there's simply no cluster to
  receive the resources.

## `create-cluster` fails, or cluster status becomes `FAILED`

- **Cause:** rootless Docker/Podman (k3s needs privileged access; error
  mentions `permission denied`), the Docker socket isn't mounted into Floci, or
  Docker is out of memory.
- **Diagnose:** `docker compose -f compose.floci.yaml logs floci`
- **Fix:** use Docker Desktop / rootful Docker, confirm the socket mount in
  `compose.floci.yaml`, give Docker ≥ 4 GB memory, then recreate the cluster
  (confirm before deleting the failed one).

## `docker push` → `http: server gave HTTP response to HTTPS client` / TLS error

- **Cause:** newer Docker Engine with the containerd image store treats
  `*.localhost` registry hostnames as HTTPS, but Floci's ECR is plain HTTP.
- **Fix:** add `000000000000.dkr.ecr.us-east-1.localhost:4566` to Docker's
  `insecure-registries` (Docker Desktop → Settings → Docker Engine), Apply &
  Restart, push again. Also confirm `*.localhost` resolves to 127.0.0.1 on the
  machine (`ping 000000000000.dkr.ecr.us-east-1.localhost`).

## Pod stuck in `ImagePullBackOff` / `ErrImagePull`

- **Cause:** image/tag not in ECR, a typo in the URI, or the cluster was
  created before Floci's registry mirror/network settings were in place.
- **Diagnose:**
  ```bash
  aws ecr list-images --repository-name <repo>
  kubectl describe pod -n <ns> <pod>     # read the Events section
  ```
- **Fix:** push the exact tag the manifest names. If the image is there but
  the cluster still can't reach the registry, check that
  `FLOCI_SERVICES_DOCKER_NETWORK` matches the compose network name, then
  recreate the cluster (the mirror config is captured at creation time).

## Pod or PVC stuck in `Pending`

- **Cause:** an unbound `PersistentVolumeClaim` — the cluster has no default
  StorageClass (this matches real EKS without the EBS CSI driver). Less often:
  insufficient resources.
- **Diagnose:** `kubectl get storageclass`, `kubectl get pvc -n <ns>`,
  `kubectl describe pod <pod> -n <ns>`.
- **Fix:** set `FLOCI_SERVICES_EKS_DEFAULT_STORAGE_CLASS: "true"` in
  `compose.floci.yaml`, restart Floci, and recreate the cluster.

## App pod `CrashLoopBackOff`, DB not ready

- **Cause:** app started before the database was accepting connections.
- **Diagnose:** `kubectl logs <pod> -n <ns>`.
- **Fix:** ensure the DB Service name matches the app's host env var, add a
  `readinessProbe` to the DB, and rely on the app's connection retry.

## Code change doesn't show up after `docker push`

- **Cause:** same tag re-pushed with `imagePullPolicy: IfNotPresent`, so the
  node keeps its cached copy.
- **Fix:** push a new tag (`v2`) and `kubectl set image ...` (or edit the
  manifest and re-apply). Teaching point: immutable tags make rollouts and
  rollbacks predictable.

## `kubectl get ... -w` never returns to the prompt

- **Not an error.** `-w`/`--watch` streams live updates by design.
- **Fix:** press **Ctrl-C** (clean SIGINT) to stop the watch. Do NOT use Ctrl-Z
  (that only suspends it as a stopped job). Same applies to `port-forward`.

## Can't reach the app from the browser

- **Cause:** the Service is internal to the cluster, and the k3s node doesn't
  publish NodePorts to your laptop. A `LoadBalancer` Service's external IP
  will stay `<pending>` locally.
- **Fix:** `kubectl port-forward -n <ns> service/<svc> 8080:80`, then open
  `http://localhost:8080`. Keep that terminal open while you use the app.

## `Conflict. The container name "/floci" is already in use`

- **Cause:** a `floci` container from an earlier run (or another project)
  already exists.
- **Diagnose:** `docker ps -a --filter name=floci`
- **Fix (confirm first — destructive):** `docker rm -f floci`, then
  `docker compose -f compose.floci.yaml up -d`. Floci keeps state in memory, so
  only that old instance's emulated resources are lost.

## Leftover `floci-eks-<cluster>` container after stopping Floci

- **Cause:** Floci was stopped before the cluster was deleted.
- **Fix (confirm first — destructive):** `docker rm -f floci-eks-<cluster>`.
  Next time, run `aws eks delete-cluster` before `docker compose ... down`.

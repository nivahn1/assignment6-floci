# Local Kubernetes / minikube troubleshooting

Common failures students hit, with the underlying cause and the fix. Diagnose
before changing manifests — most issues are cluster/state problems, not YAML.

## `dial tcp [::1]:8080: connect: connection refused` on `kubectl apply`

- **Cause:** kubectl has no reachable API server, so it falls back to the
  historic default `localhost:8080`. Almost always the cluster isn't running or
  no context is set.
- **Diagnose:**
  ```bash
  minikube status
  kubectl config current-context
  ```
  `Profile "minikube" not found` / `current-context is not set` confirms it.
- **Fix:** `minikube start` (creates the cluster **and** sets the kubectl
  context). Then re-apply.
- **Note:** `--validate=false` does NOT help — validation isn't the real
  problem; there's simply no cluster to receive the resources.

## Pod stuck in `ErrImageNeverPull` / `ImagePullBackOff`

- **Cause (Never):** `imagePullPolicy: Never` but the image was never built
  inside minikube's Docker daemon.
- **Fix:** build into minikube *before* applying:
  ```bash
  eval $(minikube docker-env)
  docker build -f Dockerfile --target <stage> -t <name>:<tag> .
  ```
  Verify with `minikube image ls | grep <name>`.
- **Cause (BackOff):** wrong image name/tag or private registry auth.

## Pod stuck in `Pending`

- **Cause:** unschedulable — often an unbound `PersistentVolumeClaim` or
  insufficient resources.
- **Diagnose:** `kubectl describe pod <pod> -n <ns>` and
  `kubectl get pvc -n <ns>`.

## App pod `CrashLoopBackOff`, DB not ready

- **Cause:** app started before the database was accepting connections.
- **Diagnose:** `kubectl logs <pod> -n <ns>`.
- **Fix:** ensure the DB Service name matches the app's host env var, add a
  `readinessProbe` to the DB, and rely on the app's connection retry.

## `kubectl get ... -w` never returns to the prompt

- **Not an error.** `-w`/`--watch` streams live updates by design.
- **Fix:** press **Ctrl-C** (clean SIGINT) to stop the watch. Do NOT use Ctrl-Z
  (that only suspends it as a stopped job). Same applies to `port-forward`.

## Service has no external IP / can't reach the app

- **Cause:** on minikube, `LoadBalancer` external IP stays `<pending>` without a
  tunnel.
- **Fix:** `minikube service <svc> -n <ns>` (opens a browser) or
  `kubectl port-forward -n <ns> service/<svc> 8080:80`, or run
  `minikube tunnel` in a separate terminal.

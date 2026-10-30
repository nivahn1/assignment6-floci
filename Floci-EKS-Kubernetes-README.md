# Student Guide: Running the App on Emulated AWS EKS (Floci)

This guide walks you through taking the app's Docker Compose stack and running
it on Kubernetes inside an **emulated AWS account** provided by
[Floci](https://github.com/floci-io/floci). It uses the Copilot **skill** and
**agent** that ship with this repository. What you have to hand in is in
[Floci-EKS-Assignment.md](./Floci-EKS-Assignment.md).

> This is a **stage-2** activity. You should already be comfortable with Docker
> and Docker Compose. Here you meet Kubernetes and the AWS deployment workflow
> locally, as a stepping stone toward scaling components and deploying to a
> real cloud provider.

### Why Floci instead of minikube?

minikube gives you "a Kubernetes cluster." Floci gives you "an AWS account":
you create the cluster with `aws eks create-cluster`, push your image to
**ECR**, and log `kubectl` in with **IAM** credentials. That's the same workflow
you'll use on real AWS later, but it's free, works offline, and runs on your
laptop.

| Concept | minikube version | Floci version |
|---------|------------------|---------------|
| Start a cluster | `minikube start` | `docker compose -f compose.floci.yaml up -d` + `aws eks create-cluster` |
| Get the image into the cluster | `eval $(minikube docker-env)` then build | build, then `docker push` to ECR |
| Connect `kubectl` | automatic | `aws eks update-kubeconfig` |
| Who are you? | nobody (local admin) | an IAM user with an access key |
| Open the app | `minikube service` | `kubectl port-forward` |
| Delete the cluster | `minikube delete` | `aws eks delete-cluster` |

The Kubernetes manifests in `k8s/` are almost identical to the minikube ones.
Only `k8s/40-app.yaml` changed: the image now comes from ECR and the Service is
`ClusterIP`.

---

## 0. Prerequisites (install once)

Install these on your laptop (Windows, macOS, or Linux):

- **Docker Desktop** (or rootful Docker Engine on Linux). Give it **at least
  4 GB of memory** (Settings → Resources); the Kubernetes node runs inside
  Docker. Rootless Docker/Podman will **not** work, because the node needs
  privileged access.
- **AWS CLI v2** (recent version): https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- **kubectl**: https://kubernetes.io/docs/tasks/tools/
- **VS Code** with the **GitHub Copilot** and **Copilot Chat** extensions

You do **not** need minikube or a real AWS account.

Verify:

```bash
docker --version
aws --version
kubectl version --client
```

---

## 1. Get the code

1. **Fork** this repository to your own account.
2. **Clone** your fork and check out the assignment branch.
3. Open the **repository root folder** in VS Code, so `.github/agents/` sits at
   the workspace root and Copilot can find the agent.

> **Run every command in this guide from the repository root**, the folder that
> contains `Dockerfile`, `compose.floci.yaml` and `k8s/`. Check with
> `ls Dockerfile`.

---

## 2. Select the "K8s Floci Tutor" agent

1. Open the **Chat** view (the Copilot Chat icon in the Activity Bar, or
   `Ctrl/Cmd` + `Alt/Option` + `I`).
2. Click the **agent/mode dropdown** at the top of the chat input box.
3. Choose **K8s Floci Tutor**.

Don't see it? See **Troubleshooting** at the bottom.

Then type something like:

> Convert `compose.prod.yaml` and the `Dockerfile` into Kubernetes manifests and
> help me run the app on an EKS cluster in Floci.

The agent reads the compose file and Dockerfile, shows you the Compose →
Kubernetes mapping, writes the manifests into `k8s/`, and walks you through the
commands below. **You run them.**

---

## 3. Deploy

### 3.1 Start Floci

```bash
docker compose -f compose.floci.yaml up -d
docker ps --filter name=floci      # STATUS should say "Up"
```

### 3.2 Point your terminal at Floci (do this in EVERY new terminal)

macOS / Linux / Git Bash / WSL:

```bash
source scripts/floci-env.sh
```

Windows PowerShell (note the leading dot and space):

```powershell
. ./scripts/floci-env.ps1
```

You should see:

```
floci-env: ready. AWS -> http://localhost:4566 as arn:aws:iam::000000000000:user/student
```

What the script does:
1. Sets `AWS_ENDPOINT_URL=http://localhost:4566`, so every `aws` command goes
   to Floci and **never to real AWS**.
2. Creates an IAM user named `student` with an access key, and switches your
   terminal to it. Floci won't let its shared `test`/`test` login administer a
   Kubernetes cluster, just as real AWS wouldn't hand cluster-admin to an
   anonymous key.
3. Saves the key in `.floci/` (git-ignored) so your next terminal reuses it.

These keys exist only inside Floci on your laptop. They are not real AWS
credentials. Open `scripts/floci-env.sh` to read exactly what it runs.

> ⚠️ The variables only live in the terminal where you sourced the script. If
> you open a new terminal or VS Code restarts its terminal, source it again.
> Forgetting this is the #1 cause of `Unauthorized` errors.

### 3.3 Build the image and push it to ECR

```bash
# Create the repository (like creating a repo on Docker Hub).
# "RepositoryAlreadyExistsException" just means it's already there; that's fine.
aws ecr create-repository --repository-name todo-app

# Log Docker in to the registry. Floci accepts any login, but this is the
# same command you'll use on real AWS.
aws ecr get-login-password | docker login --username AWS --password-stdin \
  000000000000.dkr.ecr.us-east-1.localhost:4566

# Build the bundled app and tag it with the ECR repository URI.
# (This also runs the backend tests; the build stops if one fails.)
docker build -f Dockerfile --target final \
  -t 000000000000.dkr.ecr.us-east-1.localhost:4566/todo-app:v1 .

docker push 000000000000.dkr.ecr.us-east-1.localhost:4566/todo-app:v1
aws ecr list-images --repository-name todo-app     # should list imageTag v1
```

> `000000000000` is Floci's emulated AWS account ID. On real AWS it would be
> your 12-digit account ID and the host would end in `amazonaws.com`.

### 3.4 Create the EKS cluster and connect kubectl

```bash
aws eks create-cluster \
  --name todo-cluster \
  --role-arn arn:aws:iam::000000000000:role/eks-role \
  --resources-vpc-config 'subnetIds=[],securityGroupIds=[]'
```

Keep the single quotes around `'subnetIds=[],securityGroupIds=[]'`. Without
them, zsh (the macOS default shell) fails with `no matches found`.

Floci starts a real Kubernetes (k3s) node in Docker. Wait for it, then connect:

```bash
aws eks wait cluster-active --name todo-cluster    # silent; up to a couple of minutes
aws eks update-kubeconfig --name todo-cluster
kubectl get nodes                                  # one node, STATUS Ready
```

`update-kubeconfig` adds the cluster to `~/.kube/config`. Every `kubectl`
command then runs `aws eks get-token` behind the scenes to log in as your IAM
user. That's why each terminal needs step 3.2.

### 3.5 Deploy the app

```bash
kubectl apply -f k8s/
kubectl get pods -n todo-app -w      # wait for both pods to be Running and 1/1, then Ctrl-C
kubectl get pvc -n todo-app          # mysql-pvc should be Bound
```

The app pod may restart once or twice while MySQL starts up. That's normal.

### 3.6 Open the app

```bash
kubectl port-forward -n todo-app service/app-service 8080:80
```

Open http://localhost:8080, add a few todo items, and leave the terminal open
while you use the app. Press Ctrl-C to stop forwarding.

### 3.7 Capture your evidence

In a terminal where you've sourced the env script:

```bash
scripts/floci-status.sh | tee floci-evidence.txt
```

PowerShell:

```powershell
./scripts/floci-status.ps1 *>&1 | Tee-Object floci-evidence.txt
```

This is a **read-only** snapshot of your identity, ECR image, cluster, pods,
and a live request to the app. It changes nothing, so it's also the first thing
to run whenever something seems wrong.

---

## 4. Changing the code

There is no `docker-env` trick here. The cluster pulls from ECR, just like on
real AWS. After a code change:

```bash
docker build -f Dockerfile --target final \
  -t 000000000000.dkr.ecr.us-east-1.localhost:4566/todo-app:v2 .
docker push 000000000000.dkr.ecr.us-east-1.localhost:4566/todo-app:v2
kubectl set image -n todo-app deployment/todo-app \
  app=000000000000.dkr.ecr.us-east-1.localhost:4566/todo-app:v2
kubectl rollout status -n todo-app deployment/todo-app
```

Then update the tag in `k8s/40-app.yaml` so the YAML matches what's running.
If you re-push the **same** tag, the node keeps its cached copy and your change
won't appear.

---

## 5. Shutting down: the layers of "stop"

The agent will ask for confirmation before running anything destructive.

| Docker Compose | Kubernetes / Floci equivalent | Keeps your data? |
|----------------|-------------------------------|------------------|
| `docker compose down` | `kubectl delete -f k8s/` (remove workloads, keep cluster) | ⚠️ no: deletes the namespace and its PVC |
| `docker compose down -v` | `kubectl delete -f k8s/` **+ delete the PVC** | ❌ no |
| delete the cluster | `aws eks delete-cluster --name todo-cluster` | ❌ no |
| delete everything | delete the cluster, then `docker compose -f compose.floci.yaml down` | ❌ no |

> **Treat Floci as disposable.** By default Floci keeps its state in memory, so
> when Floci stops, the emulated account (ECR images, IAM user, cluster) is
> forgotten. That's fine: the whole setup is the runbook in section 3, so
> rebuilding costs a few minutes, not your work. Your manifests and code live
> in Git, not in the cluster. Next session, start again at step 3.1; the env
> script notices Floci was reset and creates a fresh IAM key.

### Recommended end-of-session teardown

```bash
kubectl delete -f k8s/                        # remove the app (wipes MySQL data)
aws eks delete-cluster --name todo-cluster    # removes the k3s node container
docker compose -f compose.floci.yaml down     # stop Floci
docker ps -a --filter name=floci              # should list nothing left over
```

Delete the cluster **before** stopping Floci. If Floci goes first, the k3s
container can be left behind; remove it with `docker rm -f floci-eks-todo-cluster`
(confirm the name with the `docker ps -a` line above).

---

## Troubleshooting

Run `scripts/floci-status.sh` first. Most problems show up in its output.

**The "K8s Floci Tutor" agent isn't in the dropdown.**
- Make sure you opened the **repository root** as the workspace, so
  `.github/agents/` sits at the root.
- Reload the window: Command Palette → **Developer: Reload Window**.
- Right-click in the Chat view → **Diagnostics** to see loaded agents/skills.

**`Conflict. The container name "/floci" is already in use`**
- An old Floci container exists. Check it with `docker ps -a --filter name=floci`,
  remove it with `docker rm -f floci`, then start again.

**`floci-env: Floci isn't answering`**
- Floci isn't running yet, or is still starting. Run step 3.1, wait a few
  seconds, then source the script again.

**`ls: Dockerfile: No such file or directory`, or `kubectl apply -f k8s/` finds nothing**
- You're not in the repository root. `cd` to your clone and try again.

**`aws` commands hang, or mention real AWS / `amazonaws.com`.**
- This terminal hasn't sourced the env script. Run step 3.2.

**`kubectl` says `Unauthorized` / `You must be logged in to the server`.**
- Same cause: source the env script in this terminal.
  `aws sts get-caller-identity` should show `user/student`.

**`zsh: no matches found: subnetIds=[],securityGroupIds=[]`**
- Put single quotes around that value, as shown in step 3.4.

**`kubectl apply` fails with `connection refused`.**
- The cluster isn't running or isn't ACTIVE yet. Check
  `aws eks describe-cluster --name todo-cluster --query cluster.status` and
  `docker ps --filter name=floci-eks`. (Do NOT use `--validate=false`.)

**`aws eks create-cluster` fails with `permission denied`, or the cluster goes `FAILED`.**
- You're on rootless Docker/Podman, Floci can't reach the Docker socket, or
  Docker is out of memory. Use Docker Desktop with at least 4 GB. Check
  `docker compose -f compose.floci.yaml logs floci`.

**`docker push` fails with an HTTPS / TLS / "server gave HTTP response" error.**
- Newer Docker versions using the **containerd image store** treat
  `*.localhost` registry names as HTTPS. Add the registry to Docker's insecure
  registries (Docker Desktop → Settings → Docker Engine):
  ```json
  "insecure-registries": ["000000000000.dkr.ecr.us-east-1.localhost:4566"]
  ```
  then Apply & Restart. Docker restarting stops Floci, so start again at 3.1.

**App pod shows `ImagePullBackOff` / `ErrImagePull`.**
- The image or tag isn't in ECR: `aws ecr list-images --repository-name todo-app`.
- The tag in `k8s/40-app.yaml` doesn't match what you pushed.
- `kubectl describe pod -n todo-app -l app=todo-app` shows the exact pull error.

**`mysql` pod stuck `Pending`, `mysql-pvc` stuck `Pending`.**
- No StorageClass. Make sure `FLOCI_SERVICES_EKS_DEFAULT_STORAGE_CLASS: "true"`
  is in `compose.floci.yaml`, then recreate the cluster (the setting only
  applies to clusters created after Floci starts with it).
  Check with `kubectl get storageclass`.

**PowerShell says running scripts is disabled.**
- Allow scripts for this window only:
  `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`, then try again.

**`kubectl get ... -w` won't return to the prompt.**
- That's expected: `-w` watches for changes. Press **Ctrl-C** to stop.

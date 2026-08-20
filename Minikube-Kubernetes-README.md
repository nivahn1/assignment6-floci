# Student Guide: Running the App on Local Kubernetes (minikube)

This guide walks you through taking the app's Docker Compose stack and running
it on a local Kubernetes cluster with **minikube**. It uses the Copilot **skill**
and **agent** that ship with this repository.

> This is a **stage-2** activity. You should already be comfortable with Docker
> and Docker Compose. Here you meet Kubernetes locally, as a stepping stone
> toward a later assignment on scaling components.

---

## 0. Prerequisites (install once)

Install these on your laptop (Windows, macOS, or Linux):

- **Docker Desktop** (provides the Docker engine)
- **minikube** — https://minikube.sigs.k8s.io/docs/start/
- **kubectl** — https://kubernetes.io/docs/tasks/tools/
- **VS Code** with the **GitHub Copilot** and **Copilot Chat** extensions

Verify:

```bash
docker --version
minikube version
kubectl version --client
```

---

## 1. Get the code

1. **Fork** this repository to your own account.
2. **Clone** your fork and check out the branch your instructor specified.
3. In VS Code, **open the `adding-kubernetes-and-minikube` folder itself** (File →
   Open Folder → select `adding-kubernetes-and-minikube`).

> IMPORTANT: Open the **`adding-kubernetes-and-minikube` folder as the workspace
> root**, not a parent folder. VS Code discovers the Copilot skill and agent
> from the `.github/` folder at the workspace root. If you open a parent folder,
> the "K8s Local Tutor" agent will not appear in the dropdown.

---

## 2. Two Copilot helpers in this repo

| Helper | What it is | How you use it |
|--------|-----------|----------------|
| **`compose-to-minikube` skill** | Reusable know-how: how to convert Compose → Kubernetes and deploy to minikube | Loads automatically when you ask a matching question, or type `/compose-to-minikube` in Chat |
| **"K8s Local Tutor" agent** | A guided, guardrailed teaching persona that uses the skill | Pick it from the agent dropdown in the Chat view |

The **agent** is the recommended way to work: it explains each step, has you run
the commands yourself, and won't run destructive commands without asking.

---

## 3. Select the "K8s Local Tutor" agent

1. Open the **Chat** view (the Copilot Chat icon in the Activity Bar, or
   `Ctrl/Cmd` + `Alt/Option` + `I`).
2. At the top of the chat input box there is an **agent/mode dropdown**
   (it typically shows `Agent` or `Ask`). Click it.
3. Choose **K8s Local Tutor**.

Don't see it? See **Troubleshooting** at the bottom.

---

## 4. Ask it to convert and deploy

With the agent selected, type something like:

> Convert `compose.prod.yaml` and the `Dockerfile` into Kubernetes manifests and
> help me run the app on my local minikube cluster.

The agent will:
1. Read the compose file and Dockerfile and summarize the services.
2. Show you the Compose → Kubernetes mapping.
3. Generate manifests into a `k8s/` folder (with explanatory comments).
4. Walk you through the commands **for your OS/shell** — you run them:

```bash
minikube start
# then the docker-env line for YOUR shell (the agent will give you the right one)
#   macOS/Linux:  eval $(minikube docker-env)
#   PowerShell:   & minikube -p minikube docker-env --shell powershell | Invoke-Expression
docker build -f Dockerfile --target final -t todo-app:latest .
kubectl apply -f k8s/
kubectl get pods -n todo-app -w      # press Ctrl-C to stop watching
```

5. Show you how to open the app:

```bash
minikube service app-service -n todo-app
# or
kubectl port-forward -n todo-app service/app-service 8080:80   # then open http://localhost:8080
```

---

## 5. Shutting down: the layers of "stop"

Unlike Docker Compose, where `docker compose down` tears everything down in one
step, Kubernetes + minikube have **layers** of shutdown. Pick the one that
matches how much you want to keep. The agent will ask for confirmation before
running anything destructive.

| Docker Compose | Kubernetes / minikube equivalent | Keeps your data? |
|----------------|----------------------------------|------------------|
| `docker compose stop` | `minikube stop` (pause the whole cluster) | ✅ yes |
| `docker compose down` | `kubectl delete -f k8s/` (remove workloads, keep cluster) | ⚠️ no — see note |
| `docker compose down -v` | `kubectl delete -f k8s/` **+ delete the PVC** | ❌ no |
| delete everything | `minikube delete` (destroy the whole cluster) | ❌ no |

### Option A — Just pausing for the day (recommended)

Fastest to resume. Keeps your namespace, pods, and MySQL data intact:

```bash
minikube stop
```

Next session, run `minikube start` and everything is exactly where you left it.

### Option B — Remove the app but keep the cluster running

Analogous to `docker compose down`. Deletes the Deployments, Services,
ConfigMap, and namespace, but leaves minikube up so you can redeploy quickly:

```bash
kubectl delete -f k8s/
```

> ⚠️ **Data warning:** deleting the namespace (which `-f k8s/` includes) also
> deletes the `mysql-pvc` PersistentVolumeClaim inside it, so **MySQL data is
> wiped** — that's actually like `docker compose down -v`, not plain `down`.
> To keep your data, delete only the app/db/config and leave the namespace + PVC:
>
> ```bash
> kubectl delete -f k8s/app.yaml -f k8s/mysql.yaml -f k8s/configmap.yaml
> ```

### Option C — Full teardown (start completely fresh)

Destroys the cluster VM and everything in it:

```bash
minikube delete
```

### Best practice for this course

For day-to-day work, just `minikube stop` when you're done and `minikube start`
when you return. Only use `minikube delete` (or a namespace/PVC delete) when you
deliberately want a clean slate — there is **no undo**, and your MySQL data goes
with it.

---

## Troubleshooting

**The "K8s Local Tutor" agent isn't in the dropdown.**
- Make sure you opened the **`adding-kubernetes-and-minikube` folder** as the workspace
  root (Section 1), so `.github/agents/` sits at the root.
- Reload the window: Command Palette (`Shift`+`Cmd/Ctrl`+`P`) → **Developer:
  Reload Window**.
- Check discovery: right-click in the Chat view → **Diagnostics** to see loaded
  agents/skills and any errors. Or run **Chat: Open Customizations** and open the
  **Agents** tab.

**`kubectl apply` fails with `dial tcp [::1]:8080: connection refused`.**
- The cluster isn't running. Run `minikube start`, then retry. (Do NOT use
  `--validate=false` — that doesn't fix the real problem.)

**App pod shows `ErrImageNeverPull`.**
- You didn't build the image *into* minikube. Run the `docker-env` line for your
  shell, then `docker build ... -t todo-app:latest .`, then re-apply.

**`kubectl get ... -w` won't return to the prompt.**
- That's expected — `-w` watches for changes. Press **Ctrl-C** to stop.

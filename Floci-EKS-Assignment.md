# Assignment: Deploy the Todo App to Amazon EKS (Emulated with Floci)

In the previous assignment you converted the todo app's Compose stack into
Kubernetes manifests and ran it on **minikube**. In this assignment you deploy
the same app the way it's done on AWS: push the image to a container registry
(**ECR**), create a managed Kubernetes cluster (**EKS**), log in with an
**IAM** identity, and deploy with `kubectl`.

You won't need an AWS account or spend any money. **Floci**, a local AWS
emulator, runs an AWS-compatible ECR, EKS, IAM and STS on your laptop. The
commands you type are the same ones you'll use against real AWS later.

The step-by-step runbook is in
[Floci-EKS-Kubernetes-README.md](./Floci-EKS-Kubernetes-README.md). Use the
**K8s Floci Tutor** Copilot agent while you work.

---

## Learning objectives

By the end of this assignment you should be able to:

1. Explain how a cloud Kubernetes cluster gets your application image (build →
   tag → push to a registry → pull by the node), and why minikube's
   build-inside-the-cluster shortcut doesn't exist in the cloud.
2. Create an EKS cluster with the AWS CLI and connect `kubectl` to it with
   `aws eks update-kubeconfig`.
3. Explain how `kubectl` authenticates to EKS using an IAM identity, and why a
   shared or anonymous credential shouldn't get cluster-admin.
4. Deploy a multi-tier app (app + database with persistent storage) to EKS and
   verify it end to end.
5. Identify what changes when moving from this emulated setup to a real AWS
   account.

---

## Before you start

- You've completed the minikube assignment and know what each manifest in
  `k8s/` does.
- Docker Desktop (with at least 4 GB of memory), AWS CLI v2 and kubectl are
  installed (see section 0 of the runbook).
- You've forked and cloned this repository and opened its **root folder** in
  VS Code.

> **Use one chat session for the whole assignment.** Your curiosity report is
> generated from that session at the end.

---

## Part A: Deploy (required)

Work through sections 3.1–3.7 of the runbook with the K8s Floci Tutor agent.
You run every command yourself. The agent explains the steps and helps you
diagnose problems.

| # | Task | You're done when… |
|---|------|-------------------|
| A1 | Start Floci and point your terminal at it (`source scripts/floci-env.sh`) | `aws sts get-caller-identity` shows `user/student` in account `000000000000` |
| A2 | Create the `todo-app` ECR repository, then build and push the `final` image as `todo-app:v1` | `aws ecr list-images --repository-name todo-app` lists `v1` |
| A3 | Create the `todo-cluster` EKS cluster and connect `kubectl` | `kubectl get nodes` shows one `Ready` node |
| A4 | Apply the manifests in `k8s/` | Both pods are `Running` and `1/1`, and `mysql-pvc` is `Bound` |
| A5 | Open the app through `kubectl port-forward` and add at least three todo items | The items show in the browser and survive a page reload |
| A6 | Capture evidence with `scripts/floci-status.sh \| tee floci-evidence.txt` | The file shows your image, cluster, pods, and a JSON response from `/api/items` containing your items |

## Part B: Ship a change (required)

1. Make a small, visible change to the app. For example, change the
   `GREETING` text in `backend/src/routes/getGreeting.js` (keep the
   `greeting_from_backend` key; the client reads it).
2. Build and push it as `todo-app:v2`, then roll it out with
   `kubectl set image` and `kubectl rollout status` (runbook section 4).
3. Update the image tag in `k8s/40-app.yaml` to `v2` so your YAML matches what's
   running, and commit the change.
4. Re-run `scripts/floci-status.sh | tee floci-evidence.txt` so your evidence
   shows the pod running `v2` and the new greeting.

## Part C: Reflection (required)

Answer in `floci-reflection.md` at the repository root, in a few sentences each.
Use your own words. You may ask the agent questions, but these answers are
yours.

1. In the minikube assignment the app used `imagePullPolicy: Never`. Why does
   that not work on EKS, and what replaced it in this assignment?
2. Floci rejects the `test`/`test` keys for `kubectl`. What would go wrong if
   any shared key could get cluster-admin? What does `aws eks update-kubeconfig`
   write, and what happens each time `kubectl` talks to the cluster?
3. Without `FLOCI_SERVICES_EKS_DEFAULT_STORAGE_CLASS`, `mysql-pvc` stays
   `Pending`, which matches real EKS. What would you add to a real EKS cluster
   so the PVC binds? Should a production database run in the cluster at all?
4. List what you'd change to run this deployment on a real AWS account.
   Consider at least the registry address, credentials, how the app is exposed
   (`ClusterIP` + port-forward today), storage, and the Secret.
5. Describe one problem you hit during this assignment, how you found the
   cause, and how you fixed it. If nothing went wrong, describe what you'd
   check first if the app pod were stuck in `ImagePullBackOff`.

## Part D: Scaling preview (optional, ungraded)

Ask the agent for the stage-2 scaling scaffolding and try it: scale the app to
three replicas, add resource requests and limits, then try a
HorizontalPodAutoscaler. Write down what you observed in a short section at the
end of `floci-reflection.md`. Floci runs a single Kubernetes node, so note what
this setup *can't* show you about scaling.

---

## What to submit

Commit and push these to your fork, then submit the link as instructed in
Canvas:

| File | What it is |
|------|------------|
| `floci-evidence.txt` | Output of `scripts/floci-status.sh` after Part B |
| `k8s/40-app.yaml` | Updated to the `v2` image tag |
| Your Part B code change | e.g. `backend/src/routes/getGreeting.js` |
| `floci-reflection.md` | Your Part C answers (and Part D notes, if you did it) |
| `curiosity-report-<lastname>-<assignment>-<YYYY-MM-DD>.md` | Run `/curiosity-report` in the **same chat session** where you did the work. Don't hand-edit the transcript. |

Do **not** commit the `.floci/` folder. It holds your emulated IAM key and is
git-ignored automatically.

## How it's assessed

- **Completion:** each Part A and Part B row is visible in `floci-evidence.txt`,
  and the files above are present.
- **Reflection:** answers are accurate and specific to this deployment.
- **Curiosity:** your curiosity report is scored with the course's Curiosity
  Grader rubric. It looks at the depth of your questions and how you respond to
  errors, not how many questions you ask.

Your instructor sets the weights for each part in Canvas.

---

## Clean up

When you've submitted, follow "Recommended end-of-session teardown" in the
runbook (section 5). Delete the cluster before stopping Floci.

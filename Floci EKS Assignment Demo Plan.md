# Floci EKS Assignment Demo Plan

mbhhhhgfOct 31, 2026 · @Nivah

## The night before (about 20 minutes)

Do a full dry run and record it, so the live demo is fast and you have a backup if it isn't.

1. **Do one full dry run** of the showcase commands below, starting with step 0 (clean slate). It catches anything that changed and leaves Docker's build cache and the `mysql` and `k3s` images on your Mac, so the live run is fast.
2. **Record a backup video.** On a Mac, use QuickTime → **File → New Screen Recording** (or ⌘⇧5), then run the commands once. If the Wi-Fi or Docker misbehaves in the meeting, play the recording instead.
3. **Keep `~/floci-demo-evidence.txt`**, which step 7 saves during the dry run, as a second backup. It proves everything worked even if the live run doesn't.

## Right before the meeting (5 minutes)

Free up memory, make the screen readable, and have every tab ready.

- [ ] Quit other heavy apps, and check **Docker Desktop → Settings → Resources** is at **4 GB or more**.
- [ ] Make the VS Code terminal font bigger (⌘ +) so it reads well on a shared screen.
- [ ] Open the Bitbucket repo on the `Floci-EKS` branch.
- [ ] Open `Floci-EKS-Assignment.md`.
- [ ] Open a blank browser tab for http://localhost:8080.
- [ ] On Zoom or Teams, share your whole screen, not one window, so switching between the terminal and browser shows up.

## The demo (about 15 minutes)

Run the guided script live, and slow down at the three moments that show what students actually learn.

1. **Set the context (2 min).** Show the Bitbucket branch and the assignment handout. One line covers it: *"Same todo app and manifests as Assignment 6, but instead of minikube, students deploy the way they would on AWS: push to ECR, create an EKS cluster, log in with IAM. It's all emulated locally by Floci, so it's free and needs no AWS accounts."*
2. **Run the showcase commands (10 min).** Work through steps 0–7 of "Showcase commands, end to end" below, saying each "Say" line before you run its commands. Slow down at:
   - **The push to ECR (step 2):** this replaces minikube's `docker-env` trick.
   - **The app restarting (step 4):** Kubernetes has no `depends_on`.
   - **Items surviving the v2 rollout (step 6):** the data is in MySQL, not in the app pod.
3. **Show the student side (2 min).** Open Copilot Chat, pick **K8s Floci Tutor**, and ask something like *"why did my app pod restart twice?"* That shows the tutor agent and connects to the curiosity grading the course already uses.
4. **Close (1 min).** Show the evidence file and the "What to submit" table in the handout, so your professor sees how grading works. Run step 8 after the meeting.

## Showcase commands, end to end

Run every command from the repo root in VS Code, using two terminals: **Terminal 1** holds the port-forward, and **Terminal 2** runs everything else. Read each step's "Say" line before you run its commands.

### 0. Reset to a clean slate (Terminal 2)

**Say:** "I'll start from nothing, the way a student would on day one."

```bash
cd ~/assignment6-repo
docker rm -f $(docker ps -aq --filter name=floci)
```

If nothing is running, Docker prints `requires at least 1 argument`. That's fine.

### 1. Start Floci and log in (A1)

**Say:** "Instead of `minikube start`, we start an emulated AWS account. ECR, EKS and IAM all answer on localhost:4566. The env script makes sure nothing can reach real AWS, and logs in as an IAM user, because Floci refuses the shared test key for EKS."

```bash
docker compose -f compose.floci.yaml up -d
docker ps --filter name=floci
source scripts/floci-env.sh
aws sts get-caller-identity
```

Expect `user/student` in account `000000000000`. If `floci-env` says Floci isn't answering, wait a few seconds and source it again.

### 2. Push the image to ECR (A2)

**Say:** "In minikube we built the image inside the cluster. Real clouds don't work that way: you push to a registry and the cluster pulls. On real AWS only the account ID and the amazonaws.com host change."

```bash
aws ecr create-repository --repository-name todo-app
aws ecr get-login-password | docker login --username AWS --password-stdin 000000000000.dkr.ecr.us-east-1.localhost:4566
docker build -f Dockerfile --target final -t 000000000000.dkr.ecr.us-east-1.localhost:4566/todo-app:v1 .
docker push 000000000000.dkr.ecr.us-east-1.localhost:4566/todo-app:v1
aws ecr list-images --repository-name todo-app
```

`RepositoryAlreadyExistsException` on the first line is harmless. `list-images` should show `v1`.

### 3. Create the EKS cluster (A3)

**Say:** "This is the real `aws eks create-cluster` call. Floci starts a real Kubernetes node in Docker. From here, kubectl logs in with the IAM user on every request, exactly like real EKS."

```bash
aws eks create-cluster --name todo-cluster --role-arn arn:aws:iam::000000000000:role/eks-role --resources-vpc-config 'subnetIds=[],securityGroupIds=[]'
aws eks wait cluster-active --name todo-cluster
aws eks update-kubeconfig --name todo-cluster
kubectl get nodes
```

Keep the single quotes; zsh fails without them. The `wait` line is silent for up to a couple of minutes. `get nodes` should show one node, `Ready`.

### 4. Deploy (A4)

**Say:** "These are the same manifests as the minikube assignment; only the image and the Service type changed. Watch the app restart while MySQL starts: Kubernetes has no `depends_on`."

```bash
kubectl apply -f k8s/
kubectl get pods -n todo-app -w
```

Press Ctrl-C once both pods are `Running` and `1/1`, then:

```bash
kubectl get pvc -n todo-app
```

**Say:** "`mysql-pvc` is Bound only because we turned on a default StorageClass. Real EKS also ships without one; you'd install the EBS CSI driver."

### 5. Open the app (A5, Terminal 1)

**Say:** "The Service is internal to the cluster, so we port-forward to it. On real EKS this would be a LoadBalancer."

```bash
cd ~/assignment6-repo
source scripts/floci-env.sh
kubectl port-forward -n todo-app service/app-service 8080:80
```

Open http://localhost:8080, add three items, and reload the page to show they persist.

### 6. Ship v2 (Part B, Terminal 2)

**Say:** "This is the deployment loop: change the code, build a new tag, push, roll out. Re-pushing the same tag wouldn't update the pod, because the node keeps its cached copy."

```bash
perl -pi -e "s/const GREETING = '.*?';/const GREETING = 'Hello from EKS on Floci!';/" backend/src/routes/getGreeting.js
docker build -f Dockerfile --target final -t 000000000000.dkr.ecr.us-east-1.localhost:4566/todo-app:v2 .
docker push 000000000000.dkr.ecr.us-east-1.localhost:4566/todo-app:v2
kubectl set image -n todo-app deployment/todo-app app=000000000000.dkr.ecr.us-east-1.localhost:4566/todo-app:v2
kubectl rollout status -n todo-app deployment/todo-app
```

The first line changes the greeting; you can edit `getGreeting.js` in VS Code instead if you'd rather show it. In **Terminal 1**, the port-forward dies with the old pod, so press Ctrl-C if needed and restart it:

```bash
kubectl port-forward -n todo-app service/app-service 8080:80
```

Reload http://localhost:8080. **Say:** "New greeting, and the items survived, because they live in MySQL on the PVC, not in the app pod."

### 7. Capture the evidence (A6, Terminal 2)

**Say:** "This is what students submit: a read-only snapshot of identity, ECR, the cluster, the pods and a live request to the app."

```bash
scripts/floci-status.sh | tee ~/floci-demo-evidence.txt
```

### 8. Reset and tear down

Press Ctrl-C in Terminal 1 to stop the port-forward. Then, in Terminal 2, put the greeting back so the branch stays clean, and remove everything:

```bash
git checkout -- backend/src/routes/getGreeting.js
kubectl delete -f k8s/
aws eks delete-cluster --name todo-cluster
docker compose -f compose.floci.yaml down
```

## Questions to be ready for

Five questions are likely, and the honest answer to each is short.

| Question | Answer |
| --- | --- |
| Why not just use real AWS? | It's free, works offline, needs no student AWS accounts, and uses the same commands they'd run on AWS. |
| Why EKS instead of ECS? | It reuses Assignment 6's Kubernetes manifests, and Kubernetes skills carry over to other clouds. |
| How faithful is Floci? | Close but not perfect. The cluster reports version 1.29 while the node runs 1.34, and real EKS would need a LoadBalancer and the EBS CSI driver. Reflection question 4 covers these gaps. |
| What about Windows students? | The PowerShell scripts exist but haven't been tested on Windows yet. Offer to test them on a lab machine. |
| What if Floci changes mid-semester? | Pin the tested version in `compose.floci.yaml`. Do this before the meeting if you haven't yet. |

## If your professor wants to run it themselves

Point them to the `Floci-EKS` branch and `Floci-EKS-Kubernetes-README.md`. The runbook takes about 20 minutes on any Mac with Docker Desktop, AWS CLI v2 and kubectl installed.

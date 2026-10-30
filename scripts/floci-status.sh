#!/usr/bin/env bash
###################################################
# Read-only snapshot of your Floci + EKS deployment.
# Changes nothing, so it's safe to run any time you're unsure what state
# things are in.
#
# USAGE (after `source scripts/floci-env.sh` in the same terminal):
#   scripts/floci-status.sh                       # print to the terminal
#   scripts/floci-status.sh | tee floci-evidence.txt   # save for submission
#
# Optional overrides: CLUSTER=todo-cluster NAMESPACE=todo-app REPO=todo-app
###################################################
set -u

CLUSTER="${CLUSTER:-todo-cluster}"
NAMESPACE="${NAMESPACE:-todo-app}"
REPO="${REPO:-todo-app}"

section() { printf '\n=== %s ===\n' "$1"; }
run() { printf '$ %s\n' "$*"; "$@" 2>&1 || printf '(command exited with an error)\n'; }

# Safety: never query real AWS.
case "${AWS_ENDPOINT_URL:-}" in
  http://localhost:*|http://127.0.0.1:*) ;;
  *)
    echo "AWS_ENDPOINT_URL is '${AWS_ENDPOINT_URL:-<not set>}', not Floci." >&2
    echo "Run 'source scripts/floci-env.sh' in this terminal first." >&2
    exit 1 ;;
esac

section "Snapshot"
echo "Taken: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "AWS endpoint: $AWS_ENDPOINT_URL   region: ${AWS_DEFAULT_REGION:-?}"

section "Floci containers (Docker)"
run docker ps --filter name=floci --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

section "Who am I (IAM)"
run aws sts get-caller-identity --output table

section "ECR images in '$REPO'"
run aws ecr list-images --repository-name "$REPO" --output table

section "EKS cluster '$CLUSTER'"
run aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.{name:name,status:status,version:version,endpoint:endpoint}' --output table

section "kubectl"
run kubectl config current-context
run kubectl get nodes -o wide
run kubectl get deployments,pods,services,pvc -n "$NAMESPACE" -o wide

section "Images the pods are running"
run kubectl get pods -n "$NAMESPACE" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

section "App responds through the Service"
# A temporary port-forward on a spare port, closed again before exiting.
PF_PORT=18080
kubectl port-forward -n "$NAMESPACE" service/app-service "$PF_PORT:80" >/dev/null 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null' EXIT
sleep 3
for path in /api/greeting /api/items; do
  printf '$ curl http://localhost:%s%s\n' "$PF_PORT" "$path"
  curl -s --max-time 5 "http://localhost:$PF_PORT$path" || printf '(no response)'
  printf '\n'
done

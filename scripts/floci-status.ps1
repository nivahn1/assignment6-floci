###################################################
# Read-only snapshot of your Floci + EKS deployment (PowerShell version).
# Changes nothing, so it's safe to run any time.
#
# USAGE (after `. ./scripts/floci-env.ps1` in the same window):
#   ./scripts/floci-status.ps1
#   ./scripts/floci-status.ps1 *>&1 | Tee-Object floci-evidence.txt   # save for submission
###################################################
param(
    [string]$Cluster = "todo-cluster",
    [string]$Namespace = "todo-app",
    [string]$Repo = "todo-app"
)

function Section($t) { Write-Output ""; Write-Output "=== $t ===" }
function Run([string]$cmd) {
    Write-Output "`$ $cmd"
    Invoke-Expression "$cmd 2>&1" | Out-String -Stream
    if ($LASTEXITCODE -ne 0) { Write-Output "(command exited with an error)" }
}

# Safety: never query real AWS.
if ($env:AWS_ENDPOINT_URL -notmatch '^http://(localhost|127\.0\.0\.1):') {
    Write-Error "AWS_ENDPOINT_URL is '$($env:AWS_ENDPOINT_URL)', not Floci. Run '. ./scripts/floci-env.ps1' first."
    exit 1
}

Section "Snapshot"
Write-Output ("Taken: " + (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'"))
Write-Output "AWS endpoint: $($env:AWS_ENDPOINT_URL)   region: $($env:AWS_DEFAULT_REGION)"

Section "Floci containers (Docker)"
Run "docker ps --filter name=floci --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'"

Section "Who am I (IAM)"
Run "aws sts get-caller-identity --output table"

Section "ECR images in '$Repo'"
Run "aws ecr list-images --repository-name $Repo --output table"

Section "EKS cluster '$Cluster'"
Run "aws eks describe-cluster --name $Cluster --query 'cluster.{name:name,status:status,version:version,endpoint:endpoint}' --output table"

Section "kubectl"
Run "kubectl config current-context"
Run "kubectl get nodes -o wide"
Run "kubectl get deployments,pods,services,pvc -n $Namespace -o wide"

Section "Images the pods are running"
Run "kubectl get pods -n $Namespace -o jsonpath='{range .items[*]}{.metadata.name}{`"\t`"}{.spec.containers[*].image}{`"\n`"}{end}'"

Section "App responds through the Service"
$port = 18080
$pf = Start-Process kubectl -ArgumentList "port-forward -n $Namespace service/app-service ${port}:80" -PassThru -WindowStyle Hidden
try {
    Start-Sleep -Seconds 3
    foreach ($path in "/api/greeting", "/api/items") {
        Write-Output "`$ GET http://localhost:$port$path"
        try { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 "http://localhost:$port$path").Content }
        catch { Write-Output "(no response)" }
    }
} finally {
    Stop-Process -Id $pf.Id -ErrorAction SilentlyContinue
}

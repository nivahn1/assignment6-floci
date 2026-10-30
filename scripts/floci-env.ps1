###################################################
# Point THIS PowerShell window at Floci and log in as the `student` IAM user.
#
# USAGE (Windows PowerShell or pwsh, from the repo root) - note the leading dot:
#   . ./scripts/floci-env.ps1
#
# The dot ("dot-sourcing") runs the script in your current session, so the
# environment variables stay set after it finishes. Run it again in every NEW
# window, and after restarting Floci.
#
# If PowerShell blocks the script ("running scripts is disabled"), allow it
# for this window only:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#
# What it does is explained in scripts/floci-env.sh. The keys it creates exist
# only inside Floci on your laptop; they are not real AWS credentials.
###################################################

function Invoke-FlociEnv {
    $user = if ($env:FLOCI_IAM_USER) { $env:FLOCI_IAM_USER } else { "student" }
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $flociDir = Join-Path $repoRoot ".floci"
    $keyFile = Join-Path $flociDir "$user-credentials"

    # 1. Floci endpoint + region. Any profile from ~/.aws is ignored for safety.
    $env:AWS_ENDPOINT_URL = "http://localhost:4566"
    $env:AWS_DEFAULT_REGION = "us-east-1"
    $env:AWS_REGION = "us-east-1"
    Remove-Item Env:AWS_PROFILE, Env:AWS_SESSION_TOKEN -ErrorAction SilentlyContinue

    # 2. Bootstrap login, used only to manage IAM.
    $env:AWS_ACCESS_KEY_ID = "test"
    $env:AWS_SECRET_ACCESS_KEY = "test"

    aws sts get-caller-identity *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Floci isn't answering on $($env:AWS_ENDPOINT_URL)."
        Write-Warning "Start it first:  docker compose -f compose.floci.yaml up -d"
        return
    }

    # 3a. Reuse a saved key if it still belongs to the student user in THIS Floci.
    if (Test-Path $keyFile) {
        $saved = (Get-Content $keyFile -Raw).Trim() -split '\s+'
        $env:AWS_ACCESS_KEY_ID = $saved[0]
        $env:AWS_SECRET_ACCESS_KEY = $saved[1]
        $arn = aws sts get-caller-identity --query Arn --output text 2>$null
        if ($LASTEXITCODE -eq 0 -and "$arn" -like "*:user/$user") {
            Write-Host "floci-env: ready. AWS -> $($env:AWS_ENDPOINT_URL) as $arn"
            return
        }
        $env:AWS_ACCESS_KEY_ID = "test"
        $env:AWS_SECRET_ACCESS_KEY = "test"
    }

    # 3b. Create the user (if needed) and a fresh access key.
    aws iam get-user --user-name $user *> $null
    if ($LASTEXITCODE -ne 0) {
        aws iam create-user --user-name $user | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warning "couldn't create IAM user '$user'"; return }
    }
    # Old keys can't be reused without their secret, and AWS allows two per user.
    $old = aws iam list-access-keys --user-name $user --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>$null
    foreach ($id in ("$old" -split '\s+')) {
        if ($id -and $id -ne "None") {
            aws iam delete-access-key --user-name $user --access-key-id $id *> $null
        }
    }
    $new = aws iam create-access-key --user-name $user --output json | ConvertFrom-Json
    if (-not $new) { Write-Warning "couldn't create an access key for '$user'"; return }

    New-Item -ItemType Directory -Force -Path $flociDir | Out-Null
    Set-Content -Path (Join-Path $flociDir ".gitignore") -Value "*"   # never commit these keys
    Set-Content -Path $keyFile -Value "$($new.AccessKey.AccessKeyId) $($new.AccessKey.SecretAccessKey)"

    $env:AWS_ACCESS_KEY_ID = $new.AccessKey.AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $new.AccessKey.SecretAccessKey
    $arn = aws sts get-caller-identity --query Arn --output text 2>$null
    Write-Host "floci-env: ready. AWS -> $($env:AWS_ENDPOINT_URL) as $arn"
}

Invoke-FlociEnv
Remove-Item Function:Invoke-FlociEnv

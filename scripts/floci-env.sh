# shellcheck shell=bash
###################################################
# Point THIS terminal at Floci and log in as the `student` IAM user.
#
# USAGE (macOS / Linux / Git Bash / WSL, from the repo root):
#   source scripts/floci-env.sh
#
# You must SOURCE it (not run it). Environment variables only live in the
# shell that sets them; running `./scripts/floci-env.sh` would set them in a
# throwaway child shell and your terminal would be unchanged.
#
# Run it again in every NEW terminal, and after restarting Floci.
#
# WHAT IT DOES
#   1. Sets AWS_ENDPOINT_URL=http://localhost:4566 so every `aws` command goes
#      to Floci, never to real AWS.
#   2. Uses Floci's shared bootstrap login (test/test) to create an IAM user
#      named `student` and an access key for it.
#   3. Switches this terminal to that key. kubectl needs it: Floci refuses to
#      let test/test administer an EKS cluster.
#   4. Saves the key in .floci/ (git-ignored) so the next terminal reuses it.
#
# These keys exist only inside Floci on your laptop. They are not real AWS
# credentials and are useless anywhere else.
###################################################

# Refuse to run as a child process (see USAGE).
if [ -n "${ZSH_VERSION:-}" ]; then
  case "${ZSH_EVAL_CONTEXT:-}" in *:file*) ;; *)
    echo "floci-env: run this with 'source scripts/floci-env.sh' (not ./scripts/...)" >&2
    exit 1 ;;
  esac
  eval '_floci_script="${(%):-%x}"'
elif [ -n "${BASH_VERSION:-}" ]; then
  if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "floci-env: run this with 'source scripts/floci-env.sh' (not ./scripts/...)" >&2
    exit 1
  fi
  _floci_script="${BASH_SOURCE[0]}"
else
  echo "floci-env: please use bash or zsh (PowerShell users: . ./scripts/floci-env.ps1)" >&2
  # shellcheck disable=SC2317  # reachable when not sourced
  return 1 2>/dev/null || exit 1
fi

_floci_main() {
  local repo_root keyfile user="${FLOCI_IAM_USER:-student}" key secret arn

  repo_root="$(cd "$(dirname "$_floci_script")/.." && pwd)"
  keyfile="$repo_root/.floci/${user}-credentials"

  # 1. Floci endpoint + region. Any profile from ~/.aws is ignored for safety.
  export AWS_ENDPOINT_URL="http://localhost:4566"
  export AWS_DEFAULT_REGION="us-east-1"
  export AWS_REGION="us-east-1"
  unset AWS_PROFILE AWS_SESSION_TOKEN

  # 2. Bootstrap login, used only to manage IAM.
  export AWS_ACCESS_KEY_ID="test"
  export AWS_SECRET_ACCESS_KEY="test"

  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "floci-env: Floci isn't answering on $AWS_ENDPOINT_URL." >&2
    echo "  Start it first:  docker compose -f compose.floci.yaml up -d" >&2
    echo "  Endpoint is set; you are on the bootstrap login (test/test) for now." >&2
    return 1
  fi

  # 3a. Reuse a saved key if it still belongs to the student user in THIS
  #     Floci (Floci forgets IAM users when it restarts).
  if [ -f "$keyfile" ]; then
    read -r key secret < "$keyfile"
    arn="$(AWS_ACCESS_KEY_ID="$key" AWS_SECRET_ACCESS_KEY="$secret" \
      aws sts get-caller-identity --query Arn --output text 2>/dev/null)"
    case "$arn" in
      *":user/$user")
        export AWS_ACCESS_KEY_ID="$key" AWS_SECRET_ACCESS_KEY="$secret"
        echo "floci-env: ready. AWS -> $AWS_ENDPOINT_URL as $arn"
        return 0 ;;
    esac
  fi

  # 3b. Create the user (if needed) and a fresh access key.
  if ! aws iam get-user --user-name "$user" >/dev/null 2>&1; then
    aws iam create-user --user-name "$user" >/dev/null || return 1
  fi
  # Old keys can't be reused without their secret, and AWS allows only two
  # per user, so remove them before making a new one. (Floci-only keys.)
  for key in $(aws iam list-access-keys --user-name "$user" \
      --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null); do
    [ "$key" = "None" ] || aws iam delete-access-key --user-name "$user" --access-key-id "$key" >/dev/null 2>&1
  done
  read -r key secret <<EOF
$(aws iam create-access-key --user-name "$user" \
    --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)
EOF
  if [ -z "$key" ] || [ -z "$secret" ]; then
    echo "floci-env: couldn't create an access key for '$user'." >&2
    return 1
  fi

  mkdir -p "$repo_root/.floci"
  printf '*\n' > "$repo_root/.floci/.gitignore"   # never commit these keys
  ( umask 077; printf '%s %s\n' "$key" "$secret" > "$keyfile" )

  export AWS_ACCESS_KEY_ID="$key" AWS_SECRET_ACCESS_KEY="$secret"
  arn="$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)"
  echo "floci-env: ready. AWS -> $AWS_ENDPOINT_URL as ${arn:-user/$user}"
}

_floci_main
_floci_rc=$?
unset -f _floci_main
unset _floci_script
# shellcheck disable=SC2317  # reachable: exit only applies if not sourced
return "$_floci_rc" 2>/dev/null || exit "$_floci_rc"

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Bootstrap the current git repository into a Forgejo or Gitea-compatible remote.

This script:
1. creates the target repo through the Forgejo API if it does not exist
2. pushes the current local branches and tags to the target repo

Requirements:
- git
- curl
- jq

Usage:
  bash scripts/bootstrap-forgejo-repo.sh \
    --forgejo-url https://forgejo.vcp.local \
    --username demo-admin \
    --password "$FORGEJO_ADMIN_PASSWORD" \
    --owner demo-admin \
    --owner-type user \
    --repo vcluster-platform-demo-app-template

Options:
  --forgejo-url URL        Base URL for Forgejo, for example https://forgejo.vcp.local
  --username NAME          Forgejo username used for git HTTP auth
  --token VALUE            Forgejo personal access token. Defaults to FORGEJO_TOKEN
  --password VALUE         Forgejo password for basic auth. Defaults to FORGEJO_PASSWORD
  --owner NAME             Forgejo user or org that will own the repo
  --owner-type TYPE        user or org. Default: org
  --repo NAME              Target repo name
  --default-branch NAME    Branch to set as default. Auto-detected if omitted
  --visibility VALUE       private or public. Default: private
  --description TEXT       Optional repo description
  --help                   Show this message

Notes:
- The script pushes committed git history. Uncommitted local changes are not included.
- For org repos, the token user must have permission to create repos in the org.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd" >&2
    exit 1
  fi
}

detect_default_branch() {
  local branch=""
  branch="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  branch="${branch#origin/}"
  if [[ -z "$branch" ]]; then
    branch="$(git branch --show-current 2>/dev/null || true)"
  fi
  if [[ -z "$branch" ]]; then
    branch="main"
  fi
  printf '%s\n' "$branch"
}

api_request() {
  local method="$1"
  local url="$2"
  local data="${3:-}"

  local auth_args=()
  if [[ -n "$TOKEN" ]]; then
    auth_args=(-H "Authorization: token $TOKEN")
  else
    auth_args=(-u "$USERNAME:$PASSWORD")
  fi

  if [[ -n "$data" ]]; then
    curl -fsS \
      -X "$method" \
      "${auth_args[@]}" \
      -H "Content-Type: application/json" \
      "$url" \
      -d "$data"
  else
    curl -fsS \
      -X "$method" \
      "${auth_args[@]}" \
      "$url"
  fi
}

repo_exists() {
  local status
  if [[ -n "$TOKEN" ]]; then
    status="$(curl -sS -o /dev/null -w '%{http_code}' \
      -H "Authorization: token $TOKEN" \
      "$API_BASE/repos/$OWNER/$REPO")"
  else
    status="$(curl -sS -o /dev/null -w '%{http_code}' \
      -u "$USERNAME:$PASSWORD" \
      "$API_BASE/repos/$OWNER/$REPO")"
  fi
  [[ "$status" == "200" ]]
}

create_repo() {
  local endpoint payload private_flag
  if [[ "$VISIBILITY" == "private" ]]; then
    private_flag=true
  else
    private_flag=false
  fi

  if [[ "$OWNER_TYPE" == "org" ]]; then
    endpoint="$API_BASE/orgs/$OWNER/repos"
  else
    endpoint="$API_BASE/user/repos"
  fi

  payload="$(jq -cn \
    --arg name "$REPO" \
    --arg description "$DESCRIPTION" \
    --arg default_branch "$DEFAULT_BRANCH" \
    --argjson private "$private_flag" \
    '{
      name: $name,
      description: $description,
      default_branch: $default_branch,
      private: $private,
      auto_init: false
    }')"

  echo "[INFO] Creating $OWNER_TYPE repo $OWNER/$REPO"
  api_request POST "$endpoint" "$payload" >/dev/null
}

push_refs() {
  local auth_secret auth_header branch
  if [[ -n "$TOKEN" ]]; then
    auth_secret="$TOKEN"
  else
    auth_secret="$PASSWORD"
  fi
  auth_header="$(printf '%s' "$USERNAME:$auth_secret" | base64)"

  echo "[INFO] Pushing branches to $REPO_URL"
  while IFS= read -r branch; do
    [[ -n "$branch" ]] || continue
    git -c "http.extraHeader=Authorization: Basic $auth_header" \
      push "$REPO_URL" "refs/heads/$branch:refs/heads/$branch"
  done < <(git for-each-ref --format='%(refname:short)' refs/heads)

  echo "[INFO] Pushing tags to $REPO_URL"
  git -c "http.extraHeader=Authorization: Basic $auth_header" \
    push "$REPO_URL" --tags
}

FORGEJO_URL=""
USERNAME=""
TOKEN="${FORGEJO_TOKEN:-}"
PASSWORD="${FORGEJO_PASSWORD:-}"
OWNER=""
OWNER_TYPE="org"
REPO=""
DEFAULT_BRANCH=""
VISIBILITY="private"
DESCRIPTION="Bootstrap copy of vcluster-platform-demo-app-template"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --forgejo-url)
      FORGEJO_URL="${2:-}"
      shift 2
      ;;
    --username)
      USERNAME="${2:-}"
      shift 2
      ;;
    --token)
      TOKEN="${2:-}"
      shift 2
      ;;
    --password)
      PASSWORD="${2:-}"
      shift 2
      ;;
    --owner)
      OWNER="${2:-}"
      shift 2
      ;;
    --owner-type)
      OWNER_TYPE="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --default-branch)
      DEFAULT_BRANCH="${2:-}"
      shift 2
      ;;
    --visibility)
      VISIBILITY="${2:-}"
      shift 2
      ;;
    --description)
      DESCRIPTION="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd git
require_cmd curl
require_cmd jq

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "[ERROR] Run this script from inside a git repository." >&2
  exit 1
fi

if [[ -z "$FORGEJO_URL" || -z "$USERNAME" || -z "$OWNER" || -z "$REPO" ]]; then
  echo "[ERROR] Missing required arguments." >&2
  usage >&2
  exit 1
fi

if [[ -z "$TOKEN" && -z "$PASSWORD" ]]; then
  echo "[ERROR] Provide either --token/FORGEJO_TOKEN or --password/FORGEJO_PASSWORD." >&2
  exit 1
fi

if [[ "$OWNER_TYPE" != "org" && "$OWNER_TYPE" != "user" ]]; then
  echo "[ERROR] --owner-type must be 'org' or 'user'." >&2
  exit 1
fi

if [[ "$VISIBILITY" != "private" && "$VISIBILITY" != "public" ]]; then
  echo "[ERROR] --visibility must be 'private' or 'public'." >&2
  exit 1
fi

if [[ -z "$DEFAULT_BRANCH" ]]; then
  DEFAULT_BRANCH="$(detect_default_branch)"
fi

FORGEJO_URL="${FORGEJO_URL%/}"
API_BASE="$FORGEJO_URL/api/v1"
REPO_URL="$FORGEJO_URL/$OWNER/$REPO.git"

echo "[INFO] Forgejo URL: $FORGEJO_URL"
echo "[INFO] Target repo: $OWNER/$REPO"
echo "[INFO] Default branch: $DEFAULT_BRANCH"

if repo_exists; then
  echo "[INFO] Repo already exists: $OWNER/$REPO"
else
  create_repo
fi

push_refs

echo "[INFO] Forgejo bootstrap complete."
echo "[INFO] Suggested local-contained placeholders:"
echo "  REPLACE_GIT_BASE_URL=$FORGEJO_URL"
echo "  REPLACE_IMAGE_REPOSITORY_PREFIX=${FORGEJO_URL#https://}/$OWNER"

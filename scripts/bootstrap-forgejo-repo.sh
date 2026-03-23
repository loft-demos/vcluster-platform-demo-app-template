#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Bootstrap the current git repository into a Forgejo or Gitea-compatible remote.

This script:
1. creates the target repo through the Forgejo API if it does not exist
2. pushes the selected local git refs to the target repo
3. optionally pushes the current working tree as a snapshot of the default branch

Requirements:
- git
- curl
- jq

Usage:
  bash scripts/bootstrap-forgejo-repo.sh \
    --forgejo-url http://forgejo.vcp.local \
    --username demo-admin \
    --password "$FORGEJO_ADMIN_PASSWORD" \
    --owner demo-admin \
    --owner-type user \
    --repo vcluster-platform-demo-app-template

Options:
  --forgejo-url URL        Base URL for Forgejo, for example http://forgejo.vcp.local
  --username NAME          Forgejo username used for git HTTP auth
  --token VALUE            Forgejo personal access token. Defaults to FORGEJO_TOKEN
  --password VALUE         Forgejo password for basic auth. Defaults to FORGEJO_PASSWORD
  --owner NAME             Forgejo user or org that will own the repo
  --owner-type TYPE        user or org. Default: infer from owner vs username.
  --repo NAME              Target repo name
  --default-branch NAME    Branch to set as default. Auto-detected if omitted
  --visibility VALUE       private or public. Default: private
  --description TEXT       Optional repo description
  --current-branch-only    Push only the detected default branch instead of all
                           local branches
  --skip-tags              Do not push local git tags
  --include-working-tree   Also push the current working tree to the default
                           branch without changing local git history.
  --help                   Show this message

Notes:
- Without --include-working-tree, the script pushes committed git history only.
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

check_critical_placeholders() {
  local repo_root unresolved=0
  local critical_files=(
    ".forgejo/workflows/build-push.yaml"
    "helm-chart/values.yaml"
    "vcluster-use-cases/continuous-promotion/guestbook/base/deploy.yaml"
    "vcluster-use-cases/continuous-promotion/manifests/progressive-delivery/kargo-warehouse.yaml"
    "vcluster-use-cases/continuous-promotion/manifests/pre-prod-gate/kargo-warehouse.yaml"
  )

  repo_root="$(git rev-parse --show-toplevel)"

  for file in "${critical_files[@]}"; do
    [[ -f "$repo_root/$file" ]] || continue
    if rg -n '\{REPLACE_[A-Z0-9_]+\}' "$repo_root/$file" >/dev/null 2>&1; then
      echo "[ERROR] Unresolved placeholders found in $file" >&2
      rg -n '\{REPLACE_[A-Z0-9_]+\}' "$repo_root/$file" >&2 || true
      unresolved=1
    fi
  done

  if [[ "$unresolved" == "1" ]]; then
    echo "[ERROR] Refusing to push a working-tree snapshot with unresolved placeholders in runtime-critical files." >&2
    echo "[ERROR] Re-run scripts/replace-text-local.sh from the rendered runtime checkout, then push again." >&2
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

org_exists() {
  local status
  if [[ -n "$TOKEN" ]]; then
    status="$(curl -sS -o /dev/null -w '%{http_code}' \
      -H "Authorization: token $TOKEN" \
      "$API_BASE/orgs/$OWNER")"
  else
    status="$(curl -sS -o /dev/null -w '%{http_code}' \
      -u "$USERNAME:$PASSWORD" \
      "$API_BASE/orgs/$OWNER")"
  fi
  [[ "$status" == "200" ]]
}

create_org() {
  local payload
  payload="$(jq -cn \
    --arg username "$OWNER" \
    --arg full_name "$OWNER" \
    --arg description "Bootstrap organization for $OWNER" \
    --arg visibility "private" \
    '{
      username: $username,
      full_name: $full_name,
      description: $description,
      visibility: $visibility
    }')"

  echo "[INFO] Creating org $OWNER"
  api_request POST "$API_BASE/orgs" "$payload" >/dev/null
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

  if [[ "$CURRENT_BRANCH_ONLY" == "true" ]]; then
    echo "[INFO] Pushing branch ${DEFAULT_BRANCH} to $REPO_URL"
    # Use HEAD: as the source so this works from both a checked-out branch and
    # a detached HEAD state (e.g. after `git submodule update --init`).
    git -c "http.extraHeader=Authorization: Basic $auth_header" \
      push "$REPO_URL" "HEAD:refs/heads/$DEFAULT_BRANCH"
  else
    echo "[INFO] Pushing branches to $REPO_URL"
    while IFS= read -r branch; do
      [[ -n "$branch" ]] || continue
      git -c "http.extraHeader=Authorization: Basic $auth_header" \
        push "$REPO_URL" "refs/heads/$branch:refs/heads/$branch"
    done < <(git for-each-ref --format='%(refname:short)' refs/heads)
  fi

  if [[ "$SKIP_TAGS" != "true" ]]; then
    echo "[INFO] Pushing tags to $REPO_URL"
    git -c "http.extraHeader=Authorization: Basic $auth_header" \
      push "$REPO_URL" --tags
  fi
}

push_working_tree_snapshot() {
  local auth_secret auth_header repo_root current_branch temp_dir temp_repo

  if [[ -n "$TOKEN" ]]; then
    auth_secret="$TOKEN"
  else
    auth_secret="$PASSWORD"
  fi
  auth_header="$(printf '%s' "$USERNAME:$auth_secret" | base64)"

  repo_root="$(git rev-parse --show-toplevel)"
  current_branch="$(git branch --show-current 2>/dev/null || true)"
  if [[ -z "$current_branch" ]]; then
    current_branch="$DEFAULT_BRANCH"
  fi

  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/forgejo-bootstrap.XXXXXX")"
  temp_repo="$temp_dir/repo"

  cleanup_snapshot() {
    rm -rf "$temp_dir"
  }
  trap cleanup_snapshot RETURN

  git clone --quiet --no-hardlinks "$repo_root" "$temp_repo"

  (
    cd "$temp_repo"
    git remote add forgejo "$REPO_URL"
    if git -c "http.extraHeader=Authorization: Basic $auth_header" \
      fetch forgejo "$current_branch" >/dev/null 2>&1; then
      git checkout -B "$current_branch" "FETCH_HEAD" >/dev/null 2>&1
    else
      git checkout -B "$current_branch" >/dev/null 2>&1
    fi
    rsync -a --delete --exclude '.git' "$repo_root"/ "$temp_repo"/
    git add -A
    if ! git diff --cached --quiet; then
      git config user.name "vind vCP Bootstrap"
      git config user.email "vind-vcp-bootstrap@local.invalid"
      git commit -m "Bootstrap working tree snapshot" >/dev/null
    fi
    git -c "http.extraHeader=Authorization: Basic $auth_header" \
      push --force-with-lease forgejo "HEAD:refs/heads/$current_branch"
  )
}

FORGEJO_URL=""
USERNAME=""
TOKEN="${FORGEJO_TOKEN:-}"
PASSWORD="${FORGEJO_PASSWORD:-}"
OWNER=""
OWNER_TYPE=""
REPO=""
DEFAULT_BRANCH=""
VISIBILITY="private"
DESCRIPTION="Bootstrap copy of vcluster-platform-demo-app-template"
INCLUDE_WORKING_TREE="false"
CURRENT_BRANCH_ONLY="false"
SKIP_TAGS="false"

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
    --current-branch-only)
      CURRENT_BRANCH_ONLY="true"
      shift
      ;;
    --skip-tags)
      SKIP_TAGS="true"
      shift
      ;;
    --include-working-tree)
      INCLUDE_WORKING_TREE="true"
      shift
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
require_cmd rsync

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

if [[ -n "$OWNER_TYPE" && "$OWNER_TYPE" != "org" && "$OWNER_TYPE" != "user" ]]; then
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

if [[ -z "$OWNER_TYPE" ]]; then
  if [[ "$OWNER" == "$USERNAME" ]]; then
    OWNER_TYPE="user"
  else
    OWNER_TYPE="org"
  fi
fi

echo "[INFO] Forgejo URL: $FORGEJO_URL"
echo "[INFO] Target repo: $OWNER/$REPO"
echo "[INFO] Owner type: $OWNER_TYPE"
echo "[INFO] Default branch: $DEFAULT_BRANCH"

if [[ "$OWNER_TYPE" == "org" ]]; then
  if org_exists; then
    echo "[INFO] Org already exists: $OWNER"
  else
    create_org
  fi
fi

if repo_exists; then
  echo "[INFO] Repo already exists: $OWNER/$REPO"
else
  create_repo
fi

push_refs

if [[ "$INCLUDE_WORKING_TREE" == "true" ]]; then
  check_critical_placeholders
  echo "[INFO] Pushing working tree snapshot to $DEFAULT_BRANCH"
  push_working_tree_snapshot
fi

echo "[INFO] Forgejo bootstrap complete."
echo "[INFO] Suggested local-contained placeholders:"
echo "  REPLACE_GIT_BASE_URL=http://forgejo-http.forgejo.svc.cluster.local:3000"
echo "  REPLACE_GIT_PUBLIC_URL=$FORGEJO_URL"
_forgejo_registry_host="${FORGEJO_URL#http://}"
_forgejo_registry_host="${_forgejo_registry_host#https://}"
echo "  REPLACE_IMAGE_REPOSITORY_PREFIX=${_forgejo_registry_host}/$OWNER/$REPO"

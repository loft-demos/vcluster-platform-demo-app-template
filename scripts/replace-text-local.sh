#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Local equivalent of .github/workflows/replace-text.yaml.

This script replaces the main template placeholders in local files so the repo
can be used without creating a GitHub template copy first.

Replacements:
- {REPLACE_REPO_NAME}
- {REPLACE_ORG_NAME}
- {REPLACE_VCLUSTER_NAME}
- {REPLACE_BASE_DOMAIN}
- {REPLACE_FORGEJO_USERNAME}
- {REPLACE_GIT_BASE_URL}
- {REPLACE_GIT_BASE_URL_AUTHED}
- {REPLACE_GIT_PUBLIC_URL}
- {REPLACE_ARGOCD_HOST}
- {REPLACE_APP_IMAGE_REPOSITORY}
- {REPLACE_IMAGE_REPOSITORY_PREFIX}
- {REPLACE_OCI_REGISTRY_HOST}
- {REPLACE_SNAPSHOT_OCI_REPOSITORY}
- {REPLACE_IMAGE_PULL_SOURCE_SECRET_NAME}
- {REPLACE_1PASSWORD_VAULT}
- {REPLACE_KARGO_ADMIN_PASSWORD_HASH}
- {REPLACE_KARGO_TOKEN_SIGNING_KEY}
- {REPLACE_KARGO_OIDC_SECRET}
- {REPLACE_KARGO_HOST}
- {REPLACE_KARGO_WEBHOOK_HOST}
- {REPLACE_FORGEJO_OIDC_SECRET}

Usage:
  bash scripts/replace-text-local.sh \
    --repo-name vcp-gitops \
    --org-name vcluster-demos \
    --base-domain vcp.local

Options:
  --repo-name NAME        Optional. Defaults to vcp-gitops.
  --org-name NAME         Optional. Defaults to vcluster-demos.
  --vcluster-name NAME    Optional. Defaults to repo name with trailing -app removed.
  --base-domain DOMAIN    Optional. Defaults to VCP_HOST or vcp.local.
  --forgejo-username NAME
                          Optional. Defaults to FORGEJO_ADMIN_USER, FORGEJO_USERNAME, or demo-admin.
  --git-base-url URL      Optional. Defaults to http://forgejo-http.forgejo.svc.cluster.local:3000.
  --git-base-url-authed URL
                          Optional. Defaults to http://user:pass@forgejo-http.forgejo.svc.cluster.local:3000.
  --git-public-url URL    Optional. Defaults to http://forgejo.vcp.local.
  --argocd-host HOST      Optional. Defaults to argocd.<base-domain>.
  --app-image-repository IMAGE
                          Optional. Full image repository for the demo app.
                          Defaults to <image-repository-prefix>/<repo-name>-demo-app.
  --forgejo-host HOST     Optional. Defaults to forgejo.vcp.local.
  --image-repository-prefix PREFIX
                          Optional. Defaults to forgejo.vcp.local/<org-name>/<repo-name>.
  --oci-registry-host HOST
                          Optional. Defaults to forgejo.vcp.local.
  --snapshot-oci-repository PATH
                          Optional. Defaults to ghcr.io/<org-name>/<repo-name>.
  --image-pull-source-secret-name NAME
                          Optional. Defaults to <org-name>-ghcr-write.
  --onepassword-vault NAME
                          Optional. Defaults to <org-name>.
  --kargo-admin-password-hash HASH
                          Optional. Bcrypt hash of the Kargo admin password.
                          Generate with: htpasswd -bnBC 10 "" <pw> | tr -d ':\n' | sed 's/$2y/$2a/'
                          Defaults to empty string (Kargo admin login disabled).
  --kargo-token-signing-key KEY
                          Optional. Random string used to sign Kargo API tokens.
                          Generate with: openssl rand -base64 32
                          Defaults to empty string.
  --kargo-oidc-secret SECRET
                          Optional. OIDC client secret for Kargo ↔ vCP SSO.
                          Defaults to empty string (OIDC disabled).
  --kargo-host HOST
                          Optional. External Kargo host name.
                          Defaults to kargo.<base-domain>.
  --kargo-webhook-host HOST
                          Optional. External Kargo webhook host name.
                          Defaults to kargo-webhooks.<base-domain>.
  --forgejo-oidc-secret SECRET
                          Optional. OIDC client secret for Forgejo ↔ vCP SSO.
                          Defaults to empty string (OIDC disabled).
  --include-md            Also replace in Markdown files.
  --dry-run               Print matching files but do not modify them.
  --help                  Show this message.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd" >&2
    exit 1
  fi
}

REPO_NAME="vcp-gitops"
ORG_NAME="vcluster-demos"
VCLUSTER_NAME=""
BASE_DOMAIN=""
FORGEJO_USERNAME_VALUE=""
GIT_BASE_URL=""
GIT_BASE_URL_AUTHED=""
GIT_PUBLIC_URL=""
ARGOCD_HOST=""
APP_IMAGE_REPOSITORY=""
FORGEJO_HOST=""
IMAGE_REPOSITORY_PREFIX=""
OCI_REGISTRY_HOST=""
SNAPSHOT_OCI_REPOSITORY=""
IMAGE_PULL_SOURCE_SECRET_NAME=""
ONEPASSWORD_VAULT=""
KARGO_ADMIN_PASSWORD_HASH=""
KARGO_TOKEN_SIGNING_KEY=""
KARGO_OIDC_SECRET=""
KARGO_HOST=""
KARGO_WEBHOOK_HOST=""
FORGEJO_OIDC_SECRET=""
INCLUDE_MD="false"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-name)
      REPO_NAME="${2:-}"
      shift 2
      ;;
    --org-name)
      ORG_NAME="${2:-}"
      shift 2
      ;;
    --vcluster-name)
      VCLUSTER_NAME="${2:-}"
      shift 2
      ;;
    --base-domain)
      BASE_DOMAIN="${2:-}"
      shift 2
      ;;
    --forgejo-username)
      FORGEJO_USERNAME_VALUE="${2:-}"
      shift 2
      ;;
    --git-base-url)
      GIT_BASE_URL="${2:-}"
      shift 2
      ;;
    --git-base-url-authed)
      GIT_BASE_URL_AUTHED="${2:-}"
      shift 2
      ;;
    --git-public-url)
      GIT_PUBLIC_URL="${2:-}"
      shift 2
      ;;
    --argocd-host)
      ARGOCD_HOST="${2:-}"
      shift 2
      ;;
    --app-image-repository)
      APP_IMAGE_REPOSITORY="${2:-}"
      shift 2
      ;;
    --forgejo-host)
      FORGEJO_HOST="${2:-}"
      shift 2
      ;;
    --image-repository-prefix)
      IMAGE_REPOSITORY_PREFIX="${2:-}"
      shift 2
      ;;
    --oci-registry-host)
      OCI_REGISTRY_HOST="${2:-}"
      shift 2
      ;;
    --snapshot-oci-repository)
      SNAPSHOT_OCI_REPOSITORY="${2:-}"
      shift 2
      ;;
    --image-pull-source-secret-name)
      IMAGE_PULL_SOURCE_SECRET_NAME="${2:-}"
      shift 2
      ;;
    --onepassword-vault)
      ONEPASSWORD_VAULT="${2:-}"
      shift 2
      ;;
    --kargo-admin-password-hash)
      KARGO_ADMIN_PASSWORD_HASH="${2:-}"
      shift 2
      ;;
    --kargo-token-signing-key)
      KARGO_TOKEN_SIGNING_KEY="${2:-}"
      shift 2
      ;;
    --kargo-oidc-secret)
      KARGO_OIDC_SECRET="${2:-}"
      shift 2
      ;;
    --kargo-host)
      KARGO_HOST="${2:-}"
      shift 2
      ;;
    --kargo-webhook-host)
      KARGO_WEBHOOK_HOST="${2:-}"
      shift 2
      ;;
    --forgejo-oidc-secret)
      FORGEJO_OIDC_SECRET="${2:-}"
      shift 2
      ;;
    --include-md)
      INCLUDE_MD="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
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

require_cmd rg
require_cmd perl

if [[ -z "$BASE_DOMAIN" ]]; then
  BASE_DOMAIN="${VCP_HOST:-vcp.local}"
fi

if [[ -z "$VCLUSTER_NAME" ]]; then
  VCLUSTER_NAME="${REPO_NAME%-app}"
fi

if [[ -z "$KARGO_HOST" ]]; then
  KARGO_HOST="kargo.${BASE_DOMAIN}"
fi

if [[ -z "$KARGO_WEBHOOK_HOST" ]]; then
  KARGO_WEBHOOK_HOST="kargo-webhooks.${BASE_DOMAIN}"
fi

if [[ -z "$GIT_BASE_URL" ]]; then
  GIT_BASE_URL="http://${FORGEJO_SERVICE_HOST:-forgejo-http.forgejo.svc.cluster.local:3000}"
fi

if [[ -z "$GIT_BASE_URL_AUTHED" ]]; then
  _forgejo_user="${FORGEJO_USERNAME_VALUE:-${FORGEJO_ADMIN_USER:-${FORGEJO_USERNAME:-demo-admin}}}"
  _forgejo_pass="${FORGEJO_ADMIN_PASSWORD:-${FORGEJO_PASSWORD:-vcluster-demo-admin}}"
  _forgejo_service_host="${FORGEJO_SERVICE_HOST:-forgejo-http.forgejo.svc.cluster.local:3000}"
  GIT_BASE_URL_AUTHED="http://${_forgejo_user}:${_forgejo_pass}@${_forgejo_service_host}"
fi

if [[ -z "$FORGEJO_USERNAME_VALUE" ]]; then
  FORGEJO_USERNAME_VALUE="${FORGEJO_ADMIN_USER:-${FORGEJO_USERNAME:-demo-admin}}"
fi

if [[ -z "$GIT_PUBLIC_URL" ]]; then
  GIT_PUBLIC_URL="http://${FORGEJO_HOST:-forgejo.vcp.local}"
fi

if [[ -z "$ARGOCD_HOST" ]]; then
  ARGOCD_HOST="argocd.${BASE_DOMAIN}"
fi

if [[ -z "$IMAGE_REPOSITORY_PREFIX" ]]; then
  IMAGE_REPOSITORY_PREFIX="${FORGEJO_HOST:-forgejo.vcp.local}/${ORG_NAME}/${REPO_NAME}"
fi

if [[ -z "$APP_IMAGE_REPOSITORY" ]]; then
  APP_IMAGE_REPOSITORY="${IMAGE_REPOSITORY_PREFIX}/${REPO_NAME}-demo-app"
fi

if [[ -z "$OCI_REGISTRY_HOST" ]]; then
  OCI_REGISTRY_HOST="${FORGEJO_HOST:-forgejo.vcp.local}"
fi

if [[ -z "$SNAPSHOT_OCI_REPOSITORY" ]]; then
  SNAPSHOT_OCI_REPOSITORY="ghcr.io/${ORG_NAME}/${REPO_NAME}"
fi

if [[ -z "$IMAGE_PULL_SOURCE_SECRET_NAME" ]]; then
  IMAGE_PULL_SOURCE_SECRET_NAME="${ORG_NAME}-ghcr-write"
fi

if [[ -z "$ONEPASSWORD_VAULT" ]]; then
  ONEPASSWORD_VAULT="${ORG_NAME}"
fi

declare -a globs
globs+=(--glob '*.yaml' --glob '*.yml' --glob '*.sh')
if [[ "$INCLUDE_MD" == "true" ]]; then
  globs+=(--glob '*.md')
fi

declare -a files=()
while IFS= read -r file; do
  files+=("$file")
done < <(
  rg -l \
    --hidden \
    '\{REPLACE_REPO_NAME\}|\{REPLACE_ORG_NAME\}|\{REPLACE_VCLUSTER_NAME\}|\{REPLACE_BASE_DOMAIN\}|\{REPLACE_FORGEJO_USERNAME\}|\{REPLACE_GIT_BASE_URL\}|\{REPLACE_GIT_BASE_URL_AUTHED\}|\{REPLACE_GIT_PUBLIC_URL\}|\{REPLACE_ARGOCD_HOST\}|\{REPLACE_APP_IMAGE_REPOSITORY\}|\{REPLACE_IMAGE_REPOSITORY_PREFIX\}|\{REPLACE_OCI_REGISTRY_HOST\}|\{REPLACE_SNAPSHOT_OCI_REPOSITORY\}|\{REPLACE_IMAGE_PULL_SOURCE_SECRET_NAME\}|\{REPLACE_1PASSWORD_VAULT\}|\{REPLACE_KARGO_ADMIN_PASSWORD_HASH\}|\{REPLACE_KARGO_TOKEN_SIGNING_KEY\}|\{REPLACE_KARGO_OIDC_SECRET\}|\{REPLACE_KARGO_HOST\}|\{REPLACE_KARGO_WEBHOOK_HOST\}|\{REPLACE_FORGEJO_OIDC_SECRET\}|\{REPLACE_FORGEJO_HOST\}' \
    . \
    "${globs[@]}" \
    --glob '!.git/*'
)

if [[ "${#files[@]}" -eq 0 ]]; then
  echo "[INFO] No matching files found."
  exit 0
fi

echo "[INFO] Repo name: $REPO_NAME"
echo "[INFO] Org name: $ORG_NAME"
echo "[INFO] vCluster name: $VCLUSTER_NAME"
echo "[INFO] Base domain: $BASE_DOMAIN"
echo "[INFO] Git base URL: $GIT_BASE_URL"
echo "[INFO] Git base URL (authed): ${GIT_BASE_URL_AUTHED//:*@/:***@}"
echo "[INFO] Git public URL: $GIT_PUBLIC_URL"
echo "[INFO] Argo CD host: $ARGOCD_HOST"
echo "[INFO] App image repository: $APP_IMAGE_REPOSITORY"
echo "[INFO] Image repository prefix: $IMAGE_REPOSITORY_PREFIX"
echo "[INFO] OCI registry host: $OCI_REGISTRY_HOST"
echo "[INFO] Snapshot OCI repository: $SNAPSHOT_OCI_REPOSITORY"
echo "[INFO] Image pull source secret name: $IMAGE_PULL_SOURCE_SECRET_NAME"
echo "[INFO] 1Password vault: $ONEPASSWORD_VAULT"
echo "[INFO] Kargo host: $KARGO_HOST"
echo "[INFO] Kargo webhook host: $KARGO_WEBHOOK_HOST"
echo "[INFO] Files: ${#files[@]}"

if [[ "$DRY_RUN" == "true" ]]; then
  printf '%s\n' "${files[@]}"
  exit 0
fi

FORGEJO_HOST="${FORGEJO_HOST:-forgejo.vcp.local}"
export REPO_NAME ORG_NAME VCLUSTER_NAME BASE_DOMAIN GIT_BASE_URL GIT_BASE_URL_AUTHED GIT_PUBLIC_URL ARGOCD_HOST APP_IMAGE_REPOSITORY IMAGE_REPOSITORY_PREFIX OCI_REGISTRY_HOST SNAPSHOT_OCI_REPOSITORY IMAGE_PULL_SOURCE_SECRET_NAME ONEPASSWORD_VAULT KARGO_ADMIN_PASSWORD_HASH KARGO_TOKEN_SIGNING_KEY KARGO_OIDC_SECRET KARGO_HOST KARGO_WEBHOOK_HOST FORGEJO_OIDC_SECRET FORGEJO_HOST FORGEJO_USERNAME_VALUE

for file in "${files[@]}"; do
  perl -0pi -e '
    s/\{REPLACE_REPO_NAME\}/$ENV{REPO_NAME}/g;
    s/\{REPLACE_ORG_NAME\}/$ENV{ORG_NAME}/g;
    s/\{REPLACE_VCLUSTER_NAME\}/$ENV{VCLUSTER_NAME}/g;
    s/\{REPLACE_BASE_DOMAIN\}/$ENV{BASE_DOMAIN}/g;
    s/\{REPLACE_FORGEJO_USERNAME\}/$ENV{FORGEJO_USERNAME_VALUE}/g;
    s/\{REPLACE_GIT_BASE_URL\}/$ENV{GIT_BASE_URL}/g;
    s/\{REPLACE_GIT_BASE_URL_AUTHED\}/$ENV{GIT_BASE_URL_AUTHED}/g;
    s/\{REPLACE_GIT_PUBLIC_URL\}/$ENV{GIT_PUBLIC_URL}/g;
    s/\{REPLACE_ARGOCD_HOST\}/$ENV{ARGOCD_HOST}/g;
    s/\{REPLACE_APP_IMAGE_REPOSITORY\}/$ENV{APP_IMAGE_REPOSITORY}/g;
    s/\{REPLACE_IMAGE_REPOSITORY_PREFIX\}/$ENV{IMAGE_REPOSITORY_PREFIX}/g;
    s/\{REPLACE_OCI_REGISTRY_HOST\}/$ENV{OCI_REGISTRY_HOST}/g;
    s/\{REPLACE_SNAPSHOT_OCI_REPOSITORY\}/$ENV{SNAPSHOT_OCI_REPOSITORY}/g;
    s/\{REPLACE_IMAGE_PULL_SOURCE_SECRET_NAME\}/$ENV{IMAGE_PULL_SOURCE_SECRET_NAME}/g;
    s/\{REPLACE_1PASSWORD_VAULT\}/$ENV{ONEPASSWORD_VAULT}/g;
    s/\{REPLACE_KARGO_ADMIN_PASSWORD_HASH\}/$ENV{KARGO_ADMIN_PASSWORD_HASH}/g;
    s/\{REPLACE_KARGO_TOKEN_SIGNING_KEY\}/$ENV{KARGO_TOKEN_SIGNING_KEY}/g;
    s/\{REPLACE_KARGO_OIDC_SECRET\}/$ENV{KARGO_OIDC_SECRET}/g;
    s/\{REPLACE_KARGO_HOST\}/$ENV{KARGO_HOST}/g;
    s/\{REPLACE_KARGO_WEBHOOK_HOST\}/$ENV{KARGO_WEBHOOK_HOST}/g;
    s/\{REPLACE_FORGEJO_OIDC_SECRET\}/$ENV{FORGEJO_OIDC_SECRET}/g;
    s/\{REPLACE_FORGEJO_HOST\}/$ENV{FORGEJO_HOST}/g;
  ' "$file"
done

echo "[INFO] Local replacement complete."

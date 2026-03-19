# Secret Contract

This document defines the initial secret model for repurposing this repo to run
on a self-hosted `vind` demo cluster with:

- Argo CD installed directly in the `vind` cluster
- External Secrets Operator installed directly in the `vind` cluster
- vCluster Platform installed into that same cluster
- 1Password used as the source of truth for secrets

The goal is to replace the vCluster Platform Demo Generator's secret
projection/bootstrap behavior with an explicit, documented, ESO-driven secret
contract.

## Secret Model

The secret model is split into three layers.

### 1. Manual Bootstrap Secrets

These are created manually once per environment.

| Secret | Namespace | Purpose | Notes |
| --- | --- | --- | --- |
| `one-password-sa-token` | `eso` | Authenticates ESO to 1Password | Required before any `ExternalSecret` can reconcile |

### 2. Management Cluster ESO Secrets

These are the first secrets pulled from 1Password into the management cluster.

| Secret | Namespace | Purpose | Expected Keys |
| --- | --- | --- | --- |
| `repo-creds-template` | `argocd` | Argo CD repo access for this cloned repo | `username`, `password` |
| `argocd-notifications-secret` | `argocd` | Argo CD notifications / wake-up / GitHub app config | `accessKey`, `githubAppID`, `githubAppInstallationID`, `githubAppPrivateKey` |
| `ghcr-login-secret` | `vcluster-platform` | Shared GHCR image pull secret | `.dockerconfigjson` |
| `github-provider-secret` | `crossplane-system` | Crossplane GitHub provider credentials | `credentials` |

### 3. Project / Use-Case ESO Secrets

These should be added after the base bootstrap is working.

| Secret | Namespace | Purpose | Expected Keys |
| --- | --- | --- | --- |
| `demo-admin-access-key` | `p-auth-core` or `p-vcluster-flux-demo` | Flux / connected-cluster / webhook wake-up flows | `accessKey` |
| `pr-github-receiver-token` | `p-auth-core` | Flux GitHub receiver webhook signing secret | `token` |
| `oidc-secret` | `p-auth-core` | Argo CD OIDC client secret for PR environments | `clientSecret` |
| `loft-demo-org-cred` | project namespaces | GitHub token or app credential for Flux / PR automation | `token` or org-specific app credential data |
| `database-connector` | `vcluster-platform` or projected project scope | vCluster Platform shared database connector config | connector-specific keys |
| `postgres-cluster-superuser` | `cnpg-system` | CNPG PostgreSQL superuser credentials | `username`, `password` (type `kubernetes.io/basic-auth`) |
| `{REPLACE_ORG_NAME}-ghcr-write-pat` | project namespace such as `p-default` | GHCR write auth for auto snapshots | org-specific credentials |

## Same-Org vs Different-Org

This repo should no longer assume that all GitHub-related credentials belong to
the same org.

Use these conceptual buckets:

| Concern | Description |
| --- | --- |
| `REPO_ORG` | The org that owns the cloned repo template |
| `IMAGE_ORG` | The org that owns GHCR images |
| `AUTOMATION_GITHUB_ORG` | The org used for PR automation, webhooks, or GitHub app credentials |

### Same-Org Mode

All three values are the same. This is the easiest setup.

### Different-Org Mode

These values are different. In that case:

- Argo CD repo credentials should be scoped to `REPO_ORG`
- GHCR pull/push credentials should be scoped to `IMAGE_ORG`
- Crossplane GitHub provider and PR/webhook credentials should be scoped to
  `AUTOMATION_GITHUB_ORG`

## Key Consumers In This Repo

The following areas are the main secret consumers:

- Argo CD repo access and notifications
- Crossplane GitHub provider
- Flux GitHub and access-key flows
- GHCR image pull and snapshot push flows
- Database connector and MySQL operator flows

## Tracked Backlog

This is the initial tracked implementation backlog for the `vind` repurpose.

### Phase 1: Bootstrap Foundation

Status: in progress

- Add [`vind-demo-cluster/README.md`](../vind-demo-cluster/README.md)
- Add [`vind-demo-cluster/eso-cluster-store.yaml`](../vind-demo-cluster/eso-cluster-store.yaml)
- Add [`vind-demo-cluster/bootstrap-external-secrets.yaml`](../vind-demo-cluster/bootstrap-external-secrets.yaml)
- Add this file, [`docs/secret-contract.md`](./secret-contract.md)

### Phase 2: Argo CD Bootstrap Path

Status: pending

- Add `vind-demo-cluster/argocd-bootstrap-application.yaml`
- Add a `vind`-specific bootstrap README section or quickstart
- Decide which app-of-apps labels are enabled by default in self-contained mode

### Phase 3: Secret Consumer Refactor

Status: pending

- Refactor secret-dependent use cases to rely on ESO-managed secrets rather
  than Demo Generator-projected secrets
- Prioritize:
  - Argo CD notifications
  - Crossplane GitHub provider
  - Flux access key flows
  - database connector

### Phase 4: Org Decoupling

Status: pending

- Separate `REPO_ORG`, `IMAGE_ORG`, and `AUTOMATION_GITHUB_ORG` in docs and
  templates
- Audit files that still hardcode `loft-demos`
- Ensure same-org and different-org modes are both documented

### Phase 5: Use-Case Compatibility Matrix

Status: pending

- Document which use cases work unchanged on `vind`
- Document which require ESO-backed secrets
- Document which require additional external infrastructure and should stay
  disabled by default

## Notes

- This document intentionally defines a contract first, not a complete
  implementation.
- Some secrets, especially `database-connector` and `loft-demo-org-cred`, need
  a final key schema decision based on the chosen same-org or different-org
  mode.
- The bootstrap manifests in `vind-demo-cluster/` only cover the initial
  management-cluster secret set.

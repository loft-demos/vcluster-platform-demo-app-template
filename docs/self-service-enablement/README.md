# Self-Service Enablement Demo Flow

This is a cross-cutting demo flow for enablement sessions focused on the self-service critical path:

- vCluster provisioning workflow
- project-based multi-tenancy
- RBAC for developers vs. platform admins

This is not a standalone deployable use case. It is a guided walkthrough built from the repo's existing platform GitOps objects plus a small set of optional use cases that deepen the story.

## Recommendation

The repo already has the core ingredients needed for this story:

- seeded projects: [`vcluster-gitops/projects/api-framework.yaml`](../../vcluster-gitops/projects/api-framework.yaml) and [`vcluster-gitops/projects/auth-core.yaml`](../../vcluster-gitops/projects/auth-core.yaml)
- seeded teams: [`vcluster-gitops/teams/teams.yaml`](../../vcluster-gitops/teams/teams.yaml)
- seeded users: [`vcluster-gitops/users/users.yaml`](../../vcluster-gitops/users/users.yaml)
- a custom project role with limited troubleshooting access: [`vcluster-gitops/project-roles/project-user-with-logs.yaml`](../../vcluster-gitops/project-roles/project-user-with-logs.yaml)
- a default self-service template and a seeded example vCluster instance: [`vcluster-gitops/virtual-cluster-templates/base/default.yaml`](../../vcluster-gitops/virtual-cluster-templates/base/default.yaml) and [`vcluster-gitops/virtual-cluster-instances/api-framework-qa.yaml`](../../vcluster-gitops/virtual-cluster-instances/api-framework-qa.yaml)

## Best-Fit Repo Setup

Minimum story:

- base GitOps bootstrap only

Recommended story:

- base GitOps bootstrap
- [`argocd-in-vcluster`](../../vcluster-use-cases/argocd-in-vcluster/README.md) enabled

Optional deeper self-service story:

- [`namespace-sync`](../../vcluster-use-cases/namespace-sync/README.md) enabled

Why these are the best fit:

- the base repo already demonstrates project scoping, template allow-lists, quotas, and team membership
- `argocd-in-vcluster` shows what happens after self-service provisioning when a team wants isolated GitOps inside its own vCluster
- `namespace-sync` is a good follow-on if you want to show how tenant-created Argo CD `Application` objects can surface back into a shared host Argo CD model

Enable the recommended add-ons directly:

```bash
kubectl -n argocd label secret cluster-local \
  argoCdInVcluster=true \
  namespaceSync=true \
  --overwrite
```

On `vind`, the closest bootstrap is:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --use-cases eso,argocd-in-vcluster,namespace-sync
```

## Demo Personas

Use the repo's seeded identities:

| Persona | Team / role in repo | Use in the demo |
| --- | --- | --- |
| `anna-smith` | `api-framework` developer | Primary self-service user |
| `eric-jones` | `auth-core` developer | Cross-project boundary check |
| `admin` / `loft-admins` | platform admin | Guardrails, approvals, and escalation path |

Relevant files:

- [`vcluster-gitops/users/users.yaml`](../../vcluster-gitops/users/users.yaml)
- [`vcluster-gitops/teams/teams.yaml`](../../vcluster-gitops/teams/teams.yaml)

## What To Prove

By the end of the session, the audience should believe:

1. developers can provision a vCluster on their own without asking the platform team for cluster-admin access
2. projects are the tenancy boundary, so teams get only the templates, clusters, and quotas assigned to them
3. RBAC can be tuned so developers get enough power to move quickly without becoming full admins

## Critical Path Demo Flow

This flow is designed for a 20 to 30 minute enablement session.

### 1. Start with the operating model

Open the Projects view and show that the repo already separates tenants into `api-framework` and `auth-core`.

Use these files as the source of truth:

- [`vcluster-gitops/projects/api-framework.yaml`](../../vcluster-gitops/projects/api-framework.yaml)
- [`vcluster-gitops/projects/auth-core.yaml`](../../vcluster-gitops/projects/auth-core.yaml)

Key points to call out:

- `api-framework` allows only `loft-cluster` and a specific set of templates
- `auth-core` has a different template allow-list
- quotas differ by project, and `api-framework` also has a per-user quota

Talk track:

> Platform admins define guardrails once at the project layer. Developers get
> self-service inside those boundaries instead of filing tickets for every new
> environment.

### 2. Show the developer-to-project mapping

Open Teams and Users next.

Use:

- [`vcluster-gitops/teams/teams.yaml`](../../vcluster-gitops/teams/teams.yaml)
- [`vcluster-gitops/users/users.yaml`](../../vcluster-gitops/users/users.yaml)

Key points to call out:

- `anna-smith` belongs to `api-framework`
- `eric-jones` belongs to `auth-core`
- both teams are owned by `loft-admins`

Talk track:

> Multi-tenancy here is project-driven, not just namespace-driven. Team
> membership determines where people can operate before we even get to the
> vCluster itself.

### 3. Provision a vCluster as the developer

Switch to the `api-framework` project and create a new vCluster from the default template.

Use these files as the backing example:

- [`vcluster-gitops/virtual-cluster-templates/base/default.yaml`](../../vcluster-gitops/virtual-cluster-templates/base/default.yaml)
- [`vcluster-gitops/virtual-cluster-instances/api-framework-qa.yaml`](../../vcluster-gitops/virtual-cluster-instances/api-framework-qa.yaml)

What to show in the UI:

- template selection is limited to what the project allows
- the developer can choose parameters like `env`, `k8sVersion`, and `sleepAfter`
- the resulting vCluster lands in the project namespace pattern rather than an arbitrary shared namespace

Talk track:

> This is the self-service moment. The platform team is not provisioning a
> cluster by hand. The developer is choosing from an approved template catalog
> with approved parameters.

If you want the fastest path, use the seeded `api-framework-qa` instance as the starting point and explain how it maps back to the project and template.

### 4. Prove the tenancy boundary

Now show what the developer cannot do.

Good proof points:

- `anna-smith` should operate in `api-framework`, not `auth-core`
- `auth-core` has a different set of allowed templates than `api-framework`
- quotas are enforced at project scope and, for `api-framework`, per user

Talk track:

> Self-service is only valuable if it does not collapse isolation. The project
> is the contract: your team gets its own policies, quotas, and approved
> templates without leaking into another team's space.

### 5. Prove the RBAC split between developer and admin

This is the most important control-plane story in the session.

Use:

- [`vcluster-gitops/projects/api-framework.yaml`](../../vcluster-gitops/projects/api-framework.yaml)
- [`vcluster-gitops/projects/auth-core.yaml`](../../vcluster-gitops/projects/auth-core.yaml)
- [`vcluster-gitops/project-roles/project-user-with-logs.yaml`](../../vcluster-gitops/project-roles/project-user-with-logs.yaml)
- [`vcluster-gitops/project-roles/README.md`](../../vcluster-gitops/project-roles/README.md)

Key contrast:

- the `api-framework` team gets `loft-management-project-user-with-vcluster-logs`
- the `auth-core` team uses the standard `loft-management-project-user`
- `loft-admins` is assigned `loft-management-project-admin`

What to demonstrate:

- developer can create and view their own vCluster instances
- developer can inspect vCluster logs in `api-framework`
- developer cannot edit project membership, project policy, or cross-project access
- platform admin can change membership, template allow-lists, and project-level policy

Talk track:

> This is the difference between self-service and unmanaged access. Developers
> get enough permission to be productive, including light troubleshooting, but
> the administrative boundary still belongs to the platform team.

### 6. Optional deep-dive: isolated GitOps inside the vCluster

If you enabled [`argocd-in-vcluster`](../../vcluster-use-cases/argocd-in-vcluster/README.md), use this as the day-2 story after provisioning.

Use:

- [`vcluster-use-cases/argocd-in-vcluster/manifests/argocd-in-vcluster-template.yaml`](../../vcluster-use-cases/argocd-in-vcluster/manifests/argocd-in-vcluster-template.yaml)
- [`vcluster-use-cases/argocd-in-vcluster/manifests/argocd-in-vcluster-instance.yaml`](../../vcluster-use-cases/argocd-in-vcluster/manifests/argocd-in-vcluster-instance.yaml)

What to show:

- a developer provisions a vCluster from a template that can opt into Argo CD
- the imported cluster labels drive an `ApplicationSet`
- Argo CD is installed inside the tenant vCluster, not shared across tenants

Talk track:

> Provisioning is only step one. The next question is how teams manage apps
> after the cluster exists. This pattern keeps GitOps isolated per tenant while
> still being bootstrapped from the platform layer.

### 7. Optional deep-dive: self-service apps with shared host Argo CD

If you enabled [`namespace-sync`](../../vcluster-use-cases/namespace-sync/README.md), use it as the follow-on to the Argo CD story.

What to show:

- tenant creates an Argo CD `Application` inside the vCluster
- the resource syncs back to the host cluster
- destination patching still routes it to the correct vCluster endpoint

Talk track:

> This is useful when the operating model wants tenant-authored app definitions
> while keeping a centralized host-side Argo CD control plane.

## Suggested Session Narrative

Keep the session framed as:

1. admin defines guardrails
2. developer self-provisions a vCluster from an approved template
3. project boundaries enforce tenancy
4. RBAC keeps developers productive without handing out platform-admin rights
5. optional add-ons show what day-2 operations look like

That ordering keeps the demo on the self-service critical path instead of getting lost in infrastructure details.

## Do We Need a New Demo Use Case?

Short answer: no, not yet.

Why:

- the core self-service story already lives in the repo's base GitOps objects
- the most relevant deep-dive extensions already exist as use cases: `argocd-in-vcluster` and `namespace-sync`
- a new use case would mostly package documentation and seeded demo data rather than introduce new product behavior

Create a new use case only if we want one of these:

- a single label that turns on a pre-baked self-service workshop environment
- additional seeded projects and users purely for enablement sessions
- a more explicit approval or request workflow demo that does not exist today
- a stronger "golden path" opinionated template catalog just for demos

If we do create one later, a better scope would be something like `self-service-guardrails` or `project-onboarding`, not a generic `self-service` use case.

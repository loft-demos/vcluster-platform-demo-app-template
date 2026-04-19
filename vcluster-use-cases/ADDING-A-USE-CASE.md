# How to Add a vCluster Demo Use Case

This guide walks through every file that needs to change when adding a new use case to this demo template.

## Concepts

Each use case follows the same activation pattern:

1. A label is set on the Argo CD `cluster-local` secret (e.g. `myFeature: 'true'`)
2. An **ApplicationSet** in `vcluster-gitops/argocd/app-of-apps/` watches for that label
3. When the label matches, the ApplicationSet creates an **Application** pointing at `vcluster-use-cases/<use-case>/apps/`
4. That Application syncs the **manifests** for the use case (Helm releases, VirtualClusterTemplates, secrets, etc.)

---

## Step 1 — Create the use case directory structure

```
vcluster-use-cases/my-feature/
├── README.md
├── apps/
│   └── my-feature-manifests.yaml        # Argo CD Application
└── manifests/
    └── *.yaml                           # Kubernetes resources for this use case
```

Many use cases work identically across all three demo environment setups (vind, managed, self-managed) with no overlay needed. Only add a local overlay when a specific environment requires different resource paths or patched manifests:

```
vcluster-use-cases/my-feature/
├── apps/
│   ├── my-feature-manifests.yaml
│   └── overlays/
│       └── local-contained/
│           ├── kustomization.yaml
│           └── patch-my-feature-manifests.yaml
└── manifests/
    ├── *.yaml
    └── overlays/
        └── local-contained/
            └── kustomization.yaml
```

---

## Step 2 — Create the Argo CD Application

**`vcluster-use-cases/my-feature/apps/my-feature-manifests.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-feature-manifests
  namespace: argocd
  labels:
    use-case.demos.vcluster.com: my-feature
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: '{REPLACE_GIT_BASE_URL}/{REPLACE_ORG_NAME}/{REPLACE_REPO_NAME}'
    targetRevision: '{REPLACE_GIT_TARGET_REVISION}'
    path: vcluster-use-cases/my-feature/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-feature-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 1m
```

> If you need multiple Applications for a use case (e.g. a Helm app + manifests), add them all to the `apps/` directory. The ApplicationSet deploys everything in that directory.

---

## Step 3 — Create the ApplicationSet

**`vcluster-gitops/argocd/app-of-apps/my-feature-appset.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-feature-cluster
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            myFeature: 'true'            # camelCase label key
  template:
    metadata:
      name: 'my-feature-apps'
      labels:
        use-case.demos.vcluster.com: my-feature
    spec:
      destination:
        server: '{{server}}'
        namespace: argocd
      project: default
      source:
        repoURL: '{REPLACE_GIT_BASE_URL}/{REPLACE_ORG_NAME}/{REPLACE_REPO_NAME}'
        targetRevision: '{REPLACE_GIT_TARGET_REVISION}'
        path: vcluster-use-cases/my-feature/apps
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - Replace=true
        retry:
          limit: 5
          backoff:
            duration: 20s
            factor: 2
            maxDuration: 3m
```

Label key convention: use **camelCase** (e.g. `myFeature`, `databaseConnector`, `autoNodes`).

---

## Step 4 — Register the AppSet in the kustomization overlay

Add a reference to the new AppSet in:

**`vcluster-gitops/argocd/app-of-apps/overlays/local-contained/kustomization.yaml`**

```yaml
resources:
  # ... existing entries ...
  - ../../my-feature-appset.yaml
```

### If vind needs a different app path (optional)

See [auto-snapshots](auto-snapshots/apps/overlays/local-contained/) for a real example of this pattern.

Create a patch file:

**`vcluster-gitops/argocd/app-of-apps/overlays/local-contained/patch-my-feature-appset.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-feature-cluster
spec:
  template:
    spec:
      source:
        path: vcluster-use-cases/my-feature/apps/overlays/local-contained
```

Then reference it in the kustomization:

```yaml
patches:
  # ... existing patches ...
  - path: patch-my-feature-appset.yaml
```

---

## Step 5 — Register the label in `use-case-labels.sh`

**`vind-demo-cluster/use-case-labels.sh`** is the canonical registry for use case names and their label keys. Three places to update:

**1. `known_use_case_entries()`** — add the pipe-separated `name|labelKey` entry:
```bash
my-feature|myFeature
```

**2. `canonical_use_case_name()`** — add a case block accepting common name variants:
```bash
my-feature|myfeature|myFeature)
  printf '%s\n' "my-feature"
  ;;
```

**3. `label_key_for_use_case()`** — map the canonical name to its label key:
```bash
my-feature) printf '%s\n' "myFeature" ;;
```

**4. `print_known_use_cases()`** — add to the human-readable list:
```bash
- my-feature
```

---

## Step 6 — Add the label to the cluster bootstrap secrets

### Self-managed demo cluster

**`self-managed-demo-cluster/argocd-cluster-bootstrap-secret.yaml`**

```yaml
metadata:
  labels:
    myFeature: 'true'    # 'true' to enable, 'false' or '' to disable
```

For vind, labels are set dynamically by the bootstrap script based on the `--use-cases` argument.

### vCP Generator approach (optional)

If the use case should be surfaced in vCP Generator-provisioned environments, update the `VirtualClusterTemplate` in the separate repo ([loft-demos/loft-demo-base](https://github.com/loft-demos/loft-demo-base)). This is not required for every use case — some may not apply to generator environments, and others may be hardcoded as always-on (e.g. `flux: 'true'`) rather than exposed as a parameter.

**1. Add a parameter definition** in the `parameters` section of `vcluster-platform-demo-template.yaml`:

```yaml
- variable: myFeature
  label: My Feature
  description: Enable the my-feature use case
  type: boolean
  defaultValue: 'false'
  section: Use Case Examples
```

**2. Add the label to the `cluster-local` Argo CD secret** in the same template:

```yaml
labels:
  myFeature: '{{ .Values.myFeature }}'
```

For use cases that should always be on in generator environments, hardcode the label to `'true'` instead of using a parameter.

### Branch-test support for generated repos

If your use case points back at this same generated repo, use `{REPLACE_GIT_TARGET_REVISION}` for Argo CD `targetRevision` values and Flux `ref.branch` values instead of hardcoding `main` or `HEAD`.

Use the placeholder for:

- `repoURL: '{REPLACE_GIT_BASE_URL}/{REPLACE_ORG_NAME}/{REPLACE_REPO_NAME}...'`
- `targetRevision:` on Argo CD `Application` or `ApplicationSet` sources
- `branch:` on Flux `GitRepository` refs

Do not use the placeholder for:

- upstream repos that are not the generated demo repo
- docs or examples that intentionally describe a fixed upstream branch
- local bootstrap apps that should follow the checked-out default branch via `HEAD`

Why this works:

- `loft-demo-base` exposes a `gitRevision` parameter on the demo generator `VirtualClusterTemplate` resource
- that value is passed into the `DemoRepository` Crossplane claim as `gitTargetRevision`
- when `gitRevision` is `main`, the generated repo keeps the normal template-copy behavior
- when `gitRevision` is not `main`, the Crossplane composition in `loft-demo-base` copies all template branches, sets the generated repo default branch to `gitTargetRevision` with a `DefaultBranch` resource, and only then writes the seed `RepositoryFile` commit that triggers the GitHub Actions `replace-text` workflow
- the `replace-text` workflow and `scripts/replace-text-local.sh` render `{REPLACE_GIT_TARGET_REVISION}` from that selected branch, so self-repo references follow the branch under test

That sequencing matters because the seed commit is what starts the generated repo bootstrap. If the default branch were still `main` at that moment, the repo could render the wrong branch into self-references.

Local validation:

```bash
bash scripts/replace-text-local.sh \
  --repo-name vcp-gitops \
  --org-name vcluster-demos \
  --git-target-revision use-case/branch-test \
  --include-md \
  --dry-run
```

Generator validation:

1. Create or update your branch in `vcluster-platform-demo-app-template`.
2. Create a vCluster Platform demo environment from the vCluster Platform Demo virtual cluster template with the `gitRevision` parameter set to that branch name.
3. Confirm the generated repo default branch matches `gitRevision`.
4. Check a few self-repo Argo CD or Flux manifests and verify they rendered `targetRevision` or `branch` to the selected branch instead of `main`.

---

## Step 7 — Write the manifests

Add your Kubernetes resources to `vcluster-use-cases/my-feature/manifests/`. Common patterns:

| Resource | Purpose |
|---|---|
| `VirtualClusterTemplate` | Define a vCluster config that end users can instantiate |
| `HelmRelease` / `Application` | Install supporting infrastructure (operators, controllers) |
| `Secret` | Credentials, connection strings (use `{REPLACE_*}` placeholders for env-specific values) |
| `VirtualClusterInstance` | A demo instance of the vCluster to show in the UI |

### Argo CD sync waves

Use `argocd.argoproj.io/sync-wave` annotations to control apply order within a sync:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"   # secrets first
    argocd.argoproj.io/sync-wave: "1"   # then infra resources
    argocd.argoproj.io/sync-wave: "2"   # then VirtualClusterInstances
```

### Text replacement placeholders

For values that differ between environments, use placeholders in your manifests. These are replaced by `scripts/replace-text-local.sh` during bootstrap:

| Placeholder | Replaced with |
|---|---|
| `{REPLACE_GIT_BASE_URL}` | External Git server URL |
| `{REPLACE_ORG_NAME}` | Git org / owner name |
| `{REPLACE_REPO_NAME}` | Git repository name |
| `{REPLACE_GIT_TARGET_REVISION}` | Generated repo branch to use for self-repo Argo CD and Flux references |
| `{REPLACE_BASE_DOMAIN}` | Base domain for ingress |
| `{REPLACE_GIT_BASE_URL_AUTHED}` | Internal authenticated Git URL |

---

## Step 8 — Write a README

Add a `README.md` to `vcluster-use-cases/my-feature/` describing: - What the use case demonstrates - Any prerequisites - How to enable it: `--use-cases my-feature` (vind) or label `myFeature: 'true'` (managed) - Key files and what they do

---

## Checklist

- [ ] `vcluster-use-cases/my-feature/apps/my-feature-manifests.yaml` — Argo CD Application
- [ ] `vcluster-use-cases/my-feature/manifests/*.yaml` — Kubernetes resources
- [ ] `vcluster-gitops/argocd/app-of-apps/my-feature-appset.yaml` — ApplicationSet
- [ ] `vcluster-gitops/argocd/app-of-apps/overlays/local-contained/kustomization.yaml` — AppSet added to resources
- [ ] `vind-demo-cluster/use-case-labels.sh` — `known_use_case_entries`, `canonical_use_case_name`, `label_key_for_use_case`, `print_known_use_cases`
- [ ] `self-managed-demo-cluster/argocd-cluster-bootstrap-secret.yaml` — label added
- [ ] Self-repo Argo CD and Flux refs use `{REPLACE_GIT_TARGET_REVISION}` instead of hardcoded `main` or `HEAD`
- [ ] `vcluster-use-cases/my-feature/README.md` — documentation

---

## Reference: `database-connector` use case

The `database-connector` use case is a good concrete example of this pattern. It has: - One Application in `apps/`: a manifests app for the use-case-specific resources - A shared CNPG dependency installed separately by `vcluster-gitops/argocd/app-of-apps/cnpg-appset.yaml` - Sync waves ordering secrets → CNPG Cluster → VirtualClusterInstance - A credential secret using `{REPLACE_DB_CONNECTOR_PASSWORD}` placeholder - Label key `databaseConnector` mapped to canonical name `database-connector`

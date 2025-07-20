# vCluster Template Version & Parameter Updater

**The `update-templates.sh` script automates updates to Kubernetes and vCluster Helm chart versions across a set of [vCluster Platform](https://www.vcluster.com) `VirtualClusterTemplate` manifests.**

It ensures that default Kubernetes versions and chart versions stay current, and injects shared parameters like `k8sVersion` and `sleepAfter` in a consistent way.

---

## Features

- Fetches the latest 4 stable Kubernetes versions (no alpha, beta, or rc)
- Updates the default Kubernetes version to second newest stable version in shared configuration
- Retrieves the latest stable `vcluster` Helm chart version
- Replaces or patches relevant fields in both versioned and unversioned `VirtualClusterTemplate` manifests
- Injects consistent parameters like `k8sVersion`, `sleepAfter`, and `env`

---

## Triggers

This script is automated by a GitHub Actions workflow (`.github/workflows/update-vct.yaml`):

- **Daily at 6:00 AM UTC**
- **Manually** via the GitHub UI ("Run workflow" button)

---

## Workflow Steps

1. **Checkout** the repo
2. **Install** required tools (`jq`, `yq`)
3. **Generate PR branch**
4. **Run** the update script: `bash scripts/update-templates.sh`
5. **Check and commit** any changes
6. **Push** the branch and optionally open a PR if there are diffs from `main`

---

## How It Works

### Kubernetes Versions

- Fetches all official Kubernetes GitHub releases
- Filters out pre-releases
- Selects the latest 4 minor versions (e.g., `v1.33.x`, `v1.32.x`, ...)
- Updates:
  - The `options` list in [`patch-k8s-versions.yaml`](../vcluster-gitops/virtual-cluster-templates/overlays/prod/patch-k8s-version.yaml) and replaces `patch-k8s-versioned.json`
  - The default Kubernetes version (`defaultValue`)

### vCluster Helm Chart Version

- Downloads and parses `https://charts.loft.sh/index.yaml`
- Selects the latest non-pre-release `vcluster` chart version
- Updates:
  - The `chart.version` field in:
    - `vcluster-gitops/virtual-cluster-templates/overlays/prod/patch-k8s-version.yaml`
    - Any matching versioned or non-versioned template files under `vcluster-use-cases/`

---

## Patch and Template Updates

### For Non-Versioned Templates

- Uses `yq` to patch `chart.version` and update shared parameters in-place
- Target: `vcluster-gitops/virtual-cluster-templates/overlays/prod/patch-k8s-version.yaml`

### For Versioned Templates

- Creates a JSON patch (`patch-k8s-versioned.json`) with:
  - Updated `chart.version`
  - Fully replaced `parameters` list
- Intended to be used as a Kustomize JSON6902 patch for overlays

### Template Discovery

- Scans for `VirtualClusterTemplate` manifests under `vcluster-use-cases/`
- For each:
  - Detects whether it's versioned (via `.spec.versions`)
  - For versioned templates, only updates `version: 1.0.0`
  - Updates the chart version inline using `sed`, preserving formatting

---

## Requirements

You need the following installed (or the GitHub Actions job will install them for you):

- `bash`
- `curl`, `sed`, `awk`, `jq`, `perl`, `find`
- [`yq`](https://github.com/mikefarah/yq) (v4) for YAML manipulation
- [`jq`](https://stedolan.github.io/jq/) for JSON generation

---

## Manual Usage

You can run the script locally as well:

```bash
bash scripts/update-templates.sh
```

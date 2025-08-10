#!/bin/bash
set -e

echo "[INFO] Fetching latest Kubernetes versions..."
K8S_API_URL="https://api.github.com/repos/kubernetes/kubernetes/releases?per_page=100"
TMP_VERSIONS="/tmp/k8s-versions.txt"
TMP_YAML="/tmp/k8s-versions.yaml"
NON_VERSIONED_PATCH_YAML="vcluster-gitops/virtual-cluster-templates/overlays/prod/patch-non-versioned.yaml"
VERSIONED_PATCH_YAML="vcluster-gitops/virtual-cluster-templates/overlays/prod/patch-versioned.yaml"

curl -s "$K8S_API_URL" | jq -r '.[] | select(.prerelease == false) | .tag_name' \
  | grep -E '^v1\.[0-9]+\.[0-9]+$' \
  | grep -v '\-alpha' | grep -v '\-beta' | grep -v '\-rc' | grep -v '\-next' \
  | sort -Vr > "$TMP_VERSIONS.all"

awk -F. '
  {
    key = $1 "." $2
    if (!seen[key]++) {
      print "- " $0
    }
  }
' "$TMP_VERSIONS.all" | head -n 4 > "$TMP_YAML"

DEFAULT_K8S=$(sed -n 2p "$TMP_YAML" | cut -d' ' -f2)
K8S_OPTIONS=$(sed 's/^- //' "$TMP_YAML" | jq -R -s -c 'split("\n") | map(select(length > 0))')

echo "[INFO] Default Kubernetes version: $DEFAULT_K8S"
echo "[INFO] Patch will include options: $K8S_OPTIONS"

REPO_URL="https://charts.loft.sh"
CHART_NAME="vcluster"

LATEST_VCLUSTER=$(curl -s "$REPO_URL/index.yaml" \
  | yq e ".entries.$CHART_NAME[].version" - \
  | grep -v '\-alpha' | grep -v '\-beta' | grep -v '\-rc' | grep -v '\-next' \
  | sort -Vr \
  | head -n1)

echo "[INFO] Latest vCluster chart version: $LATEST_VCLUSTER"

# Update non-versioned patch (YAML)
yq e -i '
  (.spec.parameters[] | select(.variable == "k8sVersion")).options = load("'"$TMP_YAML"'") |
  (.spec.parameters[] | select(.variable == "k8sVersion")).defaultValue = "'"$DEFAULT_K8S"'" |
  .spec.template.helmRelease.chart.version = "'"$LATEST_VCLUSTER"'"
' "$NON_VERSIONED_PATCH_YAML"

echo "[✔] YAML patch for non-versioned templates updated at $NON_VERSIONED_PATCH_YAML"

# Update existing YAML 6902 patch (only k8sVersion + chart version)
export TMP_YAML
export DEFAULT_K8S
export LATEST_VCLUSTER
# 1) Bump chart version op
yq e -i '
  (.[] | select(.path == "/spec/versions/0/template/helmRelease/chart/version").value)
  = strenv(LATEST_VCLUSTER)
' "$VERSIONED_PATCH_YAML"

# 2) Update k8sVersion options + default inside the parameters op
yq e -i '
  # k8sVersion options
  (.[] | select(.path == "/spec/versions/0/parameters/0").value.options)
    = load("'"$TMP_YAML"'")
  |
  # k8sVersion default
  (.[] | select(.path == "/spec/versions/0/parameters/0").value.defaultValue)
    = "'"$DEFAULT_K8S"'"
' "$VERSIONED_PATCH_YAML"

echo "[✔] YAML 6902 patch for versioned templates updated at $VERSIONED_PATCH_YAML"

echo "[INFO] Updating use case templates..."

find vcluster-use-cases -type f -name "*.yaml" | while read -r file; do
  kind=$(yq e 'select(documentIndex == 0) | .kind' "$file" 2>/dev/null || echo "")
  if [[ "$kind" != "VirtualClusterTemplate" ]]; then
    echo "  ↳ Skipping non-VirtualClusterTemplate file"
    continue
  fi
  echo "Updating $file"

  kind=$(yq e '.kind' "$file")
  [[ "$kind" != "VirtualClusterTemplate" ]] && echo "  ↳ Skipping non-template" && continue

  has_versions=$(yq e '.spec.versions | type == "!!seq"' "$file")

  # sed function used below
  sed_inplace() {
    if sed --version >/dev/null 2>&1; then
      sed -i -E "$@"
    else
      sed -i '' -E "$@"
    fi
  }

  if [[ "$has_versions" == "true" ]]; then
    echo "  ↳ Found versioned template"

    chart_version=$(yq e '.spec.versions[] | select(.version == "1.0.0") | .template.helmRelease.chart.version' "$file" | head -n1)
    if [[ "$chart_version" != "$LATEST_VCLUSTER" ]]; then
      echo "    ↳ Updating chart version to $LATEST_VCLUSTER"
      sed_inplace "/- version: 1\.0\.0/,/^[[:space:]]*- version:|^[[:space:]]*access:/ {
        /chart:/, /values:/ {
          s/^([[:space:]]*version:[[:space:]]*)[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?/\1$LATEST_VCLUSTER/
        }
      }" "$file"
    fi

  else
    echo "  ↳ Found unversioned template"

    chart_version=$(yq e '.spec.template.helmRelease.chart.version // ""' "$file")
    if [[ "$chart_version" != "$LATEST_VCLUSTER" ]]; then
      echo "    ↳ Updating chart version to $LATEST_VCLUSTER"
      sed_inplace '/chart:/,/version:/ s/(version:[[:space:]]*)[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?/\1'"$LATEST_VCLUSTER"'/' "$file"
    fi
  fi
done
#!/bin/bash
set -e

echo "[INFO] Fetching latest Kubernetes versions..."
K8S_API_URL="https://api.github.com/repos/kubernetes/kubernetes/releases?per_page=100"
TMP_VERSIONS="/tmp/k8s-versions.txt"
TMP_YAML="/tmp/k8s-versions.yaml"
PATCH_JSON="vcluster-gitops/virtual-cluster-templates/overlays/prod/patch-k8s-versioned.json"

curl -s "$K8S_API_URL" | jq -r '.[] | select(.prerelease == false) | .tag_name' \
  | grep -E '^v1\.[0-9]+\.[0-9]+$' \
  | grep -v '\-alpha' | grep -v '\-beta' | grep -v '\-rc' \
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
  | grep -v '\-alpha' | grep -v '\-beta' | grep -v '\-rc' \
  | sort -Vr \
  | head -n1)

echo "[INFO] Latest vCluster chart version: $LATEST_VCLUSTER"

# Update non-versioned patch (YAML)
yq e -i '
  (.spec.parameters[] | select(.variable == "k8sVersion")).options = load("'"$TMP_YAML"'") |
  (.spec.parameters[] | select(.variable == "k8sVersion")).defaultValue = "'"$DEFAULT_K8S"'" |
  .spec.template.helmRelease.chart.version = "'"$LATEST_VCLUSTER"'"
' vcluster-gitops/virtual-cluster-templates/overlays/prod/patch-k8s-version.yaml

# Generate versioned patch (JSON)
jq -n \
  --arg default "$DEFAULT_K8S" \
  --argjson options "$K8S_OPTIONS" \
  --arg chartVersion "$LATEST_VCLUSTER" \
  '[
    {
      "op": "replace",
      "path": "/spec/versions/0/template/helmRelease/chart/version",
      "value": $chartVersion
    },
    {
      op: "replace",
      path: "/spec/versions/0/parameters",
      value: [
        {
          variable: "k8sVersion",
          label: "k8sVersion",
          description: "Please select Kubernetes version",
          type: "string",
          options: $options,
          defaultValue: $default,
          section: "Kubernetes Environment"
        },
        {
          variable: "env",
          label: "Deployment Environment",
          description: "Environment for deployments used as cluster label",
          options: ["dev", "qa", "prod"],
          defaultValue: "dev",
          section: "Deployment Environment"
        },
        {
          variable: "sleepAfter",
          label: "Sleep After Inactivity (minutes)",
          type: "string",
          options: ["30", "45", "60", "120"],
          defaultValue: "45"
        }
      ]
    }
  ]' > "$PATCH_JSON"

echo "[✔] JSON patch written to $PATCH_JSON"

echo "[INFO] Updating templates..."

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

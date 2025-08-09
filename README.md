# vCluster Platform Demo Repository

![Supports vCluster Inception](https://img.shields.io/badge/vCluster-Inception%20Ready-blueviolet?style=flat-square&logo=kubernetes)

This repository template is configured to automatically integrate with fully managed and fully automated [**vCluster Platform Demo Generator**](./vcluster-platform-demo-generator.md), and provides a GitOps approach for managing vCluster Platform (`vcluster-gitops` directory) and selectable demo-use-cases-as-code for self-service vCluster Platform demo environments (`vcluster-use-cases` directory).

Although originally designed and optimized for a hierarchical vCluster Platform  with the fully managed [**vCluster Platform Demo Generator**] -leveraging vCluster inception- the _vCluster Platform Demo Repository_ may also be used for _standalone_ vCluster Platform demo environments where the host cluster, along with the vCluster Platform and Argo CD installations (bootstrap applications), are self-managed. See the [instructions for self managed vCluster Platform installs](./self-managed-demo-cluster/README.md).

## vCluster Platform Integration Examples

- vCluster Platform GitOps: Mainly used to create and update vCluster Platform custom resources to pre-configure the vCluster Platform Demo environment. The resources are deployed to the vCluster Platform Demo vCluster via Argo CD and Flux.
- Argo CD: Argo CD is used for vCluster Platform Demo GitOps and to install additional template selectable demo use cases as code using the [App of Apps pattern](https://argo-cd.readthedocs.io/en/latest/operator-manual/cluster-bootstrapping/#app-of-apps-pattern). Argo CD is also used to showcase vCluster Platform integrations like ephmeral virtual cluster for GitHub Pull Requests. 
- vNode: Using vNode with vCluster and vCluster Platform
- Crossplane: Crossplane highlights custom resource syncing and is used to create _ephemeral_ GitHub resources that are automatically cleaned up when a VCP demo environment vCluster is deleted.
- External Secrets Operator showcases [vCluster integration with ESO](https://www.vcluster.com/docs/vcluster/integrations/external-secrets/guide).
- vCluster [Central Admission Control](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/policies/admission-control) with Kyverno
- Flux: Showcases vCluster integration with Flux.
- MySQL Operator example that showcases using the [vCluster Platform database connector](https://www.vcluster.com/docs/platform/administer/connector/database) to provide backing stores for Platform managed vCluster instances.
- Postgres Operator showcases custom resource syncing.
- vCluster [Virtual Scheduler](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/control-plane/other/advanced/virtual-scheduler) with Volcano Scheduler and KubeRay
- vCluster Rancher integration showcases using the [vCluster Rancher Operator](https://github.com/loft-sh/vcluster-rancher-operator) with vCluster Platform managed vCluster instances

## GitHub Actions Automations

There are a number of GitHub Actions workflows included as part of this template repository. Some are used to automate the configuration and modification of the contents of the repository, while others are used to demonstrate the features and capabilities of vCluster Platform and vCluster.

### Automation Workflows

### _replace-text_

This GitHub Actions workflow replaces template values in YAML files based on the current repository name, default values and/or user-defined inputs. It’s designed to help scaffold new vCluster Platform demo repositories created from this template repository.

#### What It Does

- **Triggers** on:
  - A push to the `main` branch that modifies `helm-chart/Chart.yaml` that is pushed to the repository by a vCluster Platform Demo Generator Crossplane integration
  - A manual run via the "Run workflow" button in the GitHub UI

- **Replaces placeholders** in all `*.yaml` files using the [`flcdrg/replace-multiple-action`](https://github.com/flcdrg/replace-multiple-action) GitHub Action:
  - `{REPLACE_REPO_NAME}` → current GitHub repo name
  - `{REPLACE_ORG_NAME}` → GitHub org that owns the repo
  - `{REPLACE_VCLUSTER_NAME}` → user-supplied name or repo name with `-app` removed
  - `{REPLACE_BASE_DOMAIN}` → user-supplied base domain (defaults to `us.demo.dev`)

- **Commits changes** automatically using [`git-auto-commit-action`](https://github.com/stefanzweifel/git-auto-commit-action)

- **Deletes** any associated container image (e.g., GitHub Container Registry package) for the repo under the org, using a GitHub PAT

- **Disables itself** after running, so it’s only used once per repo initialization

### _Auto-Update vCluster Templates + K8s Versions_

This GitHub Actions workflow runs the [**update_templates.sh**](./scripts/update-templates.sh) script and creates a pull request if there are any changes.

## Integration Details

### Argo CD Integrations

vCluster Platform includes an Argo CD integration that will automatically add a vCluster instance, created with a [virtual cluster template](https://www.vcluster.com/pro/docs/virtual-clusters/templates), to Argo CD as a target cluster of an Argo CD `Application` `destination`.

*Example `management.loft.sh/v1` `VirtualClusterTemplate` manifest (with unrelated configuration execluded - [full version here](https://github.com/loft-demos/loft-demo-base/blob/main/loft/vcluster-templates.yaml)) that enables the automatic syncing of the vCluster instance created with the template to Argo CD:*

```yaml
kind: VirtualClusterTemplate
apiVersion: management.loft.sh/v1
metadata:
  name: preview-template
spec:
  displayName: vCluster.Pro Preview Template
  template:
    metadata:
      labels:
        loft.sh/import-argocd: 'true'
...
```

The virtual cluster template integration requires the [vCluster Platform Project](https://www.vcluster.com/docs/platform/administer/projects/create), where the vCluster instance is created from said template, to have the [Argo CD integration for Projects](https://www.vcluster.com/docs/platform/integrations/argocd#project-integration) enabled.

*Example `management.loft.sh/v1` `Project` manifest (with unrelated configuration execluded - [full version here](https://github.com/loft-demos/loft-demo-base/blob/main/loft/projects.yaml)) that enables the syncing of vCluster instances to Argo CD:*

```yaml
kind: Project
apiVersion: management.loft.sh/v1
metadata:
  name: api-framework
spec:
  displayName: API Framework
...
  argoCD:
    enabled: true
    cluster: loft-cluster
    namespace: argocd
    project:
      enabled: true
```

>[!IMPORTANT]
>The Argo CD instance must be in a [vCluster Platform connected cluster](https://www.vcluster.com/docs/platform/administer/clusters/connect-cluster) or in a vCluster instance that is managed by vCluster Platform. More info is available [here](https://www.vcluster.com/docs/platform/integrations/argocd).

<details>
<summary><b>Example: ApplicationSet Cluster Generator</b></summary>
>[!IMPORTANT]
>The vCluster Platform Argo CD integration, as described above, must be enabled on the vCluster Platform project the vCluster instance is created in, for the vCluster instance to be automatically added to Argo CD as an available `Application` `destination` cluster.

In addition to automatically adding/syncing vCluster instances to Argo CD, the vCluster Platform integration also syncs `instanceTemplate` `labels` of a virtual cluster template to the Argo CD cluster `Secret` generated by the integration discussed above. This integration allows the use of the `labels` as `selectors` with the [Argo CD Cluster Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/) for `ApplciationSets`.

*Example `management.loft.sh/v1` `VirtualClusterTemplate` manifest (with unrelated configuration execluded - [full version here](https://github.com/loft-demos/loft-demo-base/blob/main/loft/vcluster-templates.yaml)) that enables the automatic syncing of vCluster instances created with this template to Argo CD and adds the `spec.versions.template.metadata.labels` to the generate Argo CD Cluster `Secret`:*

```yaml
apiVersion: management.loft.sh/v1
kind: VirtualClusterTemplate
metadata:
  name: vcluster-pro-template
  labels:
    app.kubernetes.io/instance: loft-configuration
spec:
  displayName: Virtual Cluster Pro Template
...
  template:
...
  versions:
    - template:
        metadata:
          labels:
            loft.sh/import-argocd: 'true'
        instanceTemplate:
          metadata:
            labels:
              env: '{{ .Values.env }}'
              team: '{{ .Values.loft.project }}'
        pro:
          enabled: true
...
      parameters:
      ...
        - variable: env
          label: Deployment Environment
          description: Environment for deployments for this vCluster used as cluster label for Argo CD ApplicationSet Cluster Generator
          options:
            - dev
            - qa
            - prod
          defaultValue: dev
      version: 1.0.0
    - template:
        metadata: {}
        instanceTemplate:
          metadata: {}
      version: 0.0.0
...
```

In this example the value for the `instanceTemplate.metadata.labels.env` label is populated with the selected `env` parameter value, but the value also be hardcoded so that every vCluster instance created from this template had the same `env` label value. The `team` label is populated with the `project` vCluster Platform Parameter values as documented [here](https://www.vcluster.com/docs/platform/administer/templates/advanced/parameters).

The generated Argo CD Cluster `Secret` for a vCluster instance created in the `api-framework` project and using the above template:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: loft-api-framework-vcluster-api-framework-dev
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    env: dev
    loft.sh/vcluster-instance-name: api-framework-dev
    loft.sh/vcluster-instance-namespace: loft-p-api-framework
    team: api-framework
  annotations:
    co-managed-by: loft.sh
    managed-by: argocd.argoproj.io
data:
  config: >-
    ...
  name: bG9mdC1hcGktZnJhbWV3b3JrLXZjbHVzdGVyLWFwaS1mcmFtZXdvcmstZGV2
  server: >-
    ...
type: Opaque
```

With all of that in place, you would then be able to create an Argo CD `ApplicationSet` that used the Cluster Generator as below (replacing necessary values with those for your Git repository):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: REPO_NAME-env-config
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            env: "dev"
    - clusters:
        selector:
          matchLabels:
            env: "qa"
    - clusters:
        selector:
          matchLabels:
            env: "prod"
  template:
    metadata:
      # {{name}} is the name of the kubernetes cluster as selected by the spec above
      name: REPO_NAME-{{name}}
    spec:
      destination:
        # {{server}} is the url of the 
        server: '{{server}}'
        # {{metadata.labels.env}} is the value of the env label that is being used to select kubernetes clusters 
        # and used as sub-folder in the target git repository
        namespace: hello-world-app-{{metadata.labels.env}}
      info:
        - name: GitHub Repo
          value: https://github.com/loft-demos/REPO_NAME/
      project: default
      source:
        path: k8s-manifests/{{metadata.labels.env}}/
        repoURL: https://github.com/loft-demos/REPO_NAME.git
        targetRevision: main
      syncPolicy:
        automated:
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

>[!NOTE]
>The use of the `env` label as part of the `spec.template.spec.source.path` allowing vCluster instances with different `env` values to target different subdirectories in the GitHub repository for the Argo CD generated `Application`.

The resulting Argo CD `Application` for the `hello-app-a1` repository:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-app-a1-config
  namespace: argocd
spec:
  destination:
    namespace: hello-world-app
    server: >-
      https://a1.us.demo.dev/kubernetes/project/api-framework/virtualcluster/api-framework-dev
  info:
    - name: GitHub Repo
      value: https://github.com/loft-demos/hello-app-a1/
  project: default
  source:
    path: k8s-manifests/dev/
    repoURL: https://github.com/loft-demos/hello-app-a1.git
    targetRevision: main
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```
</details>

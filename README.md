# vCluster Platform Demo Repository
This repository template is used to create vCluster Platform environments via GitOps and provides demo use cases as code. The repository includes a `vcluster-gitops` directory that serves as an example of managing the vCluster Platform with GitOps using Argo CD.

## vCluster Platform Integration Examples

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
>The Argo CD instance must be in a [vCluster.Pro connected cluster](https://www.vcluster.com/pro/docs/clusters/connect-cluster) or in a vCluster instance that is managed by vCluster.Pro. More info is available [here](https://www.vcluster.com/pro/docs/virtual-clusters/argocd#enable-argo-cd-integration).

<details>
<summary><b>Example: ApplicationSet Pull Request Generator</b></summary>

Once the vCluster.Pro Argo CD integration has been enabled for the vCluster.Pro project and the virtual cluster template, an Argo CD `ApplicationSet` using the [Argo CD Pull Request Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Pull-Request/) may look something like the following:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: REPO_NAME-pr
  namespace: argocd
spec:
  generators:
  - pullRequest:
      github:
        appSecretName: loft-demo-org-cred
        # The GitHub organization or user.
        owner: loft-demos
        # The Github repository
        repo: REPO_NAME
        # (optional) use a GitHub App to access the API instead of a PAT.
        #appSecretName: github-app-repo-creds
        # Labels is used to filter the PRs that you want to target. (optional)
        labels:
        - preview-cluster-ready
      requeueAfterSeconds: 30
  template:
    metadata:
      name: 'REPO_NAME-{{branch}}-{{number}}'
    spec:
      syncPolicy:
        automated:
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
      source:
        repoURL: 'https://github.com/loft-demos/REPO_NAME.git'
        targetRevision: '{{head_sha}}'
        path: helm-chart/
        helm:
          parameters:
          - name: "image.repository"
            value: ghcr.io/loft-demos/REPO_NAME
          - name: "image.tag"
            value: "{{head_short_sha}}"
          - name: "image.args.text"
            value: "Hello from REPO_NAME pr-{{number}} commit {{head_short_sha}}"
          - name: "ingress.hosts[0].host"
            value: REPO_NAME-pr-{{number}}-LOFT_DOMAIN
          - name: ingress.hosts[0].paths[0].backend.service.name
            value: REPO_NAME
          - name: ingress.hosts[0].paths[0].backend.service.port.name
            value: http
          - name: ingress.hosts[0].paths[0].path
            value: /
          - name: ingress.hosts[0].paths[0].pathType
            value: prefix
          - name: "ingress.tls[0].hosts[0]"
            value: REPO_NAME-pr-{{number}}-LOFT_DOMAIN
      project: "default"
      destination:
        server: https://LOFT_DOMAIN/kubernetes/project/api-framework/virtualcluster/REPO_NAME-pr-{{number}}
        namespace: preview-hello-world-app
      info:
        - name: Preview App Link
          value: >-
            https://REPO_NAME-pr-{{number}}-LOFT_DOMAIN
        - name: GitHub PR
          value: >-
            https://github.com/loft-demos/REPO_NAME/pull/{{number}}
```
The `spec.template.spec.destination.server` is dynamic based on the pull request number availabe as the `{{number}}` parameter value when using the Argo CD Pull Request generator.
</details>

<details>
<summary><b>Example: ApplicationSet Cluster Generator</b></summary>
>[!IMPORTANT]
>The vCluster.Pro Argo CD integration, as described above, must be enabled on the vCluster.Pro project the vCluster instance is created in, for the vCluster instance to be automatically added to Argo CD as an available `Application` `destination` cluster.

In addition to automatically adding/syncing vCluster instances to Argo CD, the vCluster.Pro integration also syncs `instanceTemplate` `labels` of a virtual cluster template to the Argo CD cluster `Secret` generated by the integration discussed above. This integration allows the use of the `labels` as `selectors` with the [Argo CD Cluster Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/) for `ApplciationSets`.

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
In this example the value for the `instanceTemplate.metadata.labels.env` label is populated with the selected `env` parameter value, but the value also be hardcoded so that every vCluster instance created from this template had the same `env` label value. The `team` label is populated with the `project` vCluster.Pro Parameter values as documented [here](https://www.vcluster.com/pro/docs/apps/parameters#vclusterpro-parameter-values).

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

### Ephmeral Virtual Clusters for Pull Requests
Creating an ephemeral Kubernetes cluster for every GitHub pull request introduces several challenges across infrastructure, security, cost, and operational management. Here are some key considerations:

1. **Infrastructure & Performance Challenges**
  - Cluster Provisioning Overhead: Spinning up a new Kubernetes cluster for every PR requires compute resources and may lead to long provisioning times.
  - Resource Contention: In high-traffic repositories, multiple PRs could overwhelm the available infrastructure, impacting CI/CD pipeline performance.
  - Storage Management: Persistent storage can be complex in ephemeral environments, especially for stateful applications requiring data retention.
2. **Cost & Resource Management**
  - Compute Costs: Creating a cluster per PR consumes CPU, memory, and networking resources, leading to potential cost overruns if not properly managed.
  - Idle Resource Waste: If PR clusters are not properly cleaned up after merging or closing, they may linger and increase cloud costs unnecessarily.
3. **Security & Access Control**
  - Multi-Tenancy Risks: Running multiple ephemeral environments on shared infrastructure requires strict network isolation and RBAC policies to prevent unauthorized access.
  - OIDC & Authentication Complexity: Ensuring secure authentication for every ephemeral instance (especially in a dynamic environment) adds operational overhead.
  - GitHub Webhook Security: The automation that triggers ephemeral clusters must be secured to avoid unauthorized cluster creation or code execution.
4. **CI/CD Pipeline Complexity**
  - State & Data Persistence: Testing in ephemeral clusters requires handling temporary databases, caching strategies, and external dependencies.
  - PR Environment Lifecycle Management: Automating cleanup after PR closure is crucial but can be error-prone, leading to leftover resources.
  - Secret Management: Each ephemeral cluster may need different secrets or environment variables, requiring a secure and automated way to inject them.
5. **Integration with Argo CD & Crossplane**
  - Application Deployment Latency: Argo CD’s sync processes and Crossplane’s provisioning may introduce delays when spinning up environments.
  - GitHub Rate Limits: Frequent interactions with GitHub (e.g., setting up webhooks, fetching repo state) can hit API rate limits, slowing down the process.
  - Ingress & Networking: Exposing services from ephemeral clusters requires proper Ingress configuration, which can be tricky when scaling across multiple PR environments.

#### Mitigation Strategies
- **Use vCluster Instead of Full Kubernetes Clusters:** vCluster with vCluster Platform reduces resource overhead with [features like Sleep Mode](https://www.vcluster.com/docs/platform/use-platform/virtual-clusters/key-features/sleep-mode), while still providing isolation. 
- **Implement Auto-Cleanup & TTLs:** Use [vCluster Platform Auto Delete](https://www.vcluster.com/docs/platform/configure/cost-control) to automatically delete ephemeral virtual clusters after a set time to avoid resource waste.
- **Optimize CI/CD Pipelines:** Use caching and incremental builds to speed up provisioning and reduce redundant cluster setups.
- **Enforce Strong RBAC & Network Policies:** Secure ephemeral virtual clusters with least privilege access and strict namespace isolation with vCluster Platform Virtual Cluster Templates.
- **Monitor & Optimize Costs:** Leverage the vCluster Platfrom [Cost Control Dashboard](https://www.vcluster.com/docs/platform/configure/cost-control) to track and optimize ephemeral vCluster expenses.

#### Two Approaches
The examples in this repository explore two approaches for creating ephmeral GitHub pull request environments with vCluster:
- Shared Argo CD with ephemeral vCluster.
- Completely ephemeral environment with an ephemeral Argo CD deployed into the ephmeral vCluster.


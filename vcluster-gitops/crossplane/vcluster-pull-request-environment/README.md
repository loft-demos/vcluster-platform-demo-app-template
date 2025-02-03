# Ephemeral vCluster for Pull Requests
### with Ephemeral Argo CD Instance 

This setup enables the automatic creation of ephemeral PR vCluster instances for each repo pull request with the `pr-vcluster` label, to include an ephemeral Argo CD deployed inside that PR vCluster for managing the Pull Request application code changes dynamically.

## Key Components & Workflow
1. vCluster Platform
   - Utilizes the [`VirtualClusterInstance` CRD](https://www.vcluster.com/docs/platform/api/resources/virtualclusterinstance/), that is configured with a `VirtualClusterTemplate` vCluster Platform custom resource, as part of [the `pullrequestenvironments` Crossplane composition](./vcluster-pull-request-environment-composition.yaml) to dynamically provision PR vCluster instances.
   - The [`argocd` `App` custom resource](./argo-cd.yaml) deploys Argo CD inside each ephemeral vCluster, configuring an `ApplicationSet` for managing deployment of [the repo application code](https://github.com/loft-demos/vcluster-platform-demo-app-template/tree/main/src).
   - Supports SSO via OIDC provided by vCluster Platform for secure authentication.
      - [OIDC `Secret` deployed into the `vcluster-platform` namespace](./vcluster-pull-request-environment-composition.yaml#L72-L131)
      - [Argo CD OIDC configuration that is part of the `VirtualClusterTemplate` configuration](../../virtual-cluster-templates/pull-request-vcluster.yaml#L58-L62)
2. vCluster
   - The actual Kubernetes cluster used to host an ephemeral Argo CD instance and to host the Helm based application associated with the Pull Request.
   - Created via a Crossplane Claim defined in [the `xpullrequestenvironments.virtualcluster.demo.loft.sh` Composition](./vcluster-pull-request-environment-definition.yaml).
   - Configured with the [*pull-request-vcluster* `VirtualClusterTemplate`](/vcluster-pull-request-environment-composition.yaml#L37-L39).
3. Crossplane
   - Manages cloud-native resources using the [Kubernetes](https://github.com/loft-demos/loft-demo-base/tree/main/vcluster-platform-demo-generator/crossplane/provider-kubernetes) and [GitHub](https://github.com/loft-demos/loft-demo-base/tree/main/vcluster-platform-demo-generator/crossplane/provider-github) providers.
   - Uses compositions resource definitions to automate provisioning of ephemeral PR vCluster:
     - `XPullRequestEnvironment`: Creates an isolated vCluster environment for each pull request.
     - `XArgoCDWebhook`: Manages ephemeral webhooks for triggering Argo CD deployments for every commit to a Pull Request head branch.
4. Argo CD
   - There are actually two Argo CD instances used for this setup:
      1. Argo CD running in the host cluster with the [*pr-vcluster-internal-argocd*](../../argocd/pr-environments/apps/pr-vcluster-internal-argocd.yaml) `ApplicationSet` that uses the [Pull Request Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Pull-Request/) that creates a Kustomize `Application` from this [directory](../../../kustomize-pr) - that includes the `PullRequestEnvironment` Crossplane Claim - for every Pull Request that has the `pr-vcluster` label applied.
      2. The ephemeral Argo CD instance deployed inside of the PR vCluster and actually deploys the PR application [Helm chart](https://github.com/loft-demos/vcluster-platform-demo-app-template/tree/main/helm-chart) into the PR vCluster via an Argo CD `ApplicationSet` that is deployed the PR vCluster Argo CD via [the *argo-cd-pr-application-set*](../../apps/argo-cd-pr-application-set.yaml) `App` template by [the *pull-request-vcluster*](../../virtual-cluster-templates/pull-request-vcluster.yaml) `VirtualClusterTemplate` [here](../../virtual-cluster-templates/pull-request-vcluster.yaml#L116-L124).
5. Ingress Nginx Controller
   - Actually runs in the host cluster.
   - Provides ingress routing for the PR app deployed into the vCluster and the ephemeral Argo CD instance deployed in the PR vCluster by [sycing `Ingress` resources from the PR vCluster to the host cluster](../../virtual-cluster-templates/pull-request-vcluster.yaml#L176-L179).

## How It Works
- When a pull request is opened and the `pr-vcluster` label is applied to the PR, an Argo CD `ApplicationSet` using the Pull Request Generator is triggered in the Argo CD instance running in the host cluster.
   - The `ApplicationSet` generates an Argo CD Kustomize `Application` that patches (addes the PR number) and deploys a `PullRequestEnvironment` Crossplane Claim that results in the creation of a `VirtualClusterInstance` configured with a `VirtualClusterTemplate` and a Kubernetes `Secret` for vCluster Platform provided OIDC SSO for the ephemeral Argo CD instanced deployed in the PR vCluster.
- The `VirtualClusterTemplate` is configured to deploy the ephemeral Argo CD instance inside the PR vCluster, and an `ApplicationSet` that is deployed to the ephemeral Argo CD instance. That `ApplicationSet` is triggered by the same Pull Request and generates an Argo CD Helm `Application` for the Pull Request `head` commit and is deployed to the PR vCluster.
- After the Helm `Application` for the Pull Request `head` commit is deployed to the PR vCluster, the PR vCluster Argo CD Notifications controller updates the GitHub Pull Request with relevant links.
- The system integrates [OIDC-based SSO provided by vCluster Platform](https://www.vcluster.com/docs/platform/how-to/oidc-provider), allowing developers to access Argo CD securely.
- The `VirtualClusterTemplate` used for the PR vCluster is [configured with activity based Sleep Mode and Auto Delete](./virtual-cluster-templates/pull-request-vcluster.yaml#L170-L175). This allows the PR vCluster to be scaled down to zero pods by vCluster Platform when a given Pull Request remains open but the PR vCluster is not actively being used for two hours. It will also automatically delete the vCluster after the specified amount of time.
- Upon merging or closing the PR (or removing the `pr-vcluster` label), the host cluster Argo CD `ApplicationSet` triggers the deletion of the associated PR vCluster `Application` resulting in the deletion of the PR vCluster, keeping the system efficient and cost-effective.
```mermaid
flowchart LR
    PR-->Host-Argo;
    Host-Argo-->Crossplane;
    Crossplane-->PR-vCluster;
    PR-vCluster-->vCluster-Argo;
    vCluster-Argo-->PR-App;
```
This approach enables fast, isolated, and repeatable CI/CD workflows, enhancing development velocity and reducing integration risks.

## Component List

- vCluster Platform
  - `VirtualClusterInstance` CRD
  - `VirtualClusterTemplate` CRD
  - `App` CRD - Used to install Argo CD into the ephemeral vCluster instance and the Argo CD `ApplicationSet` for the GitHub repo application code
    - Argo CD `App`
    - Argo CD ApplicationSet `App`
  - SSO via OIDC
- Crossplane
  - Providers:
    - Kubernetes Provider
    - GitHub Provider
  - Compositions (with XRD and XRC/XR)
    - `XPullRequestEnvironment`
    - `XArgoCDWebhook`
- Argo CD
  - ApplicationSet using the Pull Request Generator 
- Ingress Nginx
- vCluster - created with a `VirtualClusterTemplate`
  - Argo CD
    - ApplicationSet using the Pull Request Generator

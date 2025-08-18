# Ephemeral Pull Request vCluster with Shared Argo CD

The **Ephemeral Pull Request vCluster with Shared Argo CD** pattern leverages the power of vCluster Platform to provide dynamic, isolated preview environments for GitHub Pull Requests using a GitOps-driven workflow with Argo CD. This approach uses two Argo CD `ApplicationSets`: one to spin up 1 or more ephemeral vCluster instances with a **vCluster Platform template** and different versions of Kubernetes, and another to deploy the PR preview application into those vCluster instances. The vCluster Platform automatically registers the new vCluster instances as an Argo CD app server destination by creating the Argo CD cluster secrets with the `metadata.labels` added by the `ApplicationSet` template and Virtual Cluster Template. Those labels are then used as part of trigger for the second `ApplicationSet`.

vCluster Platform SSO is also integrated with Argo CD, allowing both developers and reviewers to be granted secure, scoped access to the pull request vCluster instances and their workloads through the Argo CD UI using their existing identity provider. This model delivers full environment isolation per PR, mirrors production topology without impacting shared clusters, and avoids infrastructure bloat by reusing a single Argo CD instance and host cluster. The vCluster Platform orchestrates the entire lifecycle—provisioning, cluster registration, access management, and teardown—making ephemeral environments repeatable, secure, and scalable.

## Features Used

- vCluster Platform Project Integration with Argo CD
- vCluster Platform SSO Integration with Argo CD
- vCluster Platform Argo CD Cluster Secret Label Injection
- vCluster Platform Virtual Cluster Templates

## Overview

For the Pull Request vCluster with a shared Argo CD instance, both the PR vCluster and the PR preview app are deployed by a shared Argo CD instance using two [Argo CD `ApplicationSets`](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/) that automate the creation and management of two Argo CD `Applications` for every labeled Pull Request and a matrix of Kubernetes versions using [dynamic generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/).

1. **vCluster ApplicationSet**: The first `ApplicationSet` uses the Matrix generator to combine two Argo CD `ApplicationSet` Generators - the List generator with a list of Kubernetes versions to create vCluster instances and the Pull Request generator to only trigger allow the triggering of the `ApplicationSet` when there is an open pull request with a specific label.
2. **PR App Deployment ApplicationSet**: The second `ApplicationSet` uses the Matrix generator to combine two Argo CD `ApplicationSet` Generators - the Pull Request generator and the Cluster generator.

The only thing deployed into the vCluster is the PR preview app itself as other required dependencies, like an ingress controller, are shared from the host cluster in which the vCluster is deployed.

## PR vCluster Argo CD Flow

1. A specific GitHub label is added to the Pull Request (this example uses `create-pr-vcluster-external-argocd`) and this tiggers the first Argo CD `ApplicationSet`
2. The Argo CD `ApplicationSet`, configured with the Pull Request generator and triggered by the PR label, generates an Argo CD `Application` specific to the given Pull Request and uses Kustomize to deploy a PR specific `VirtualClusterInstance` custom resource that leverages a `VirtualClusterTemplate` custom resource for most of its configuration:

    - The Argo CD `ApplicationSet` allows using Pull Requests specific parameters, like PR number, with Kustomize patches to modify `VirtualClusterInstance` resource with the following `labels` that are then added to the vCluster Platform auto-generated Argo CD cluster `Secret` that will be used to trigger the second PR preview app `ApplicationSet`. The labels are used by the Argo CD Cluster generator to uniquely identify and target the PR vCluster for the preview app generated Argo CD `Application`:

      - `repo` the Pull Request GitHub repository
      - `prLabel` has to match `create-pr-vcluster-external-argocd`
      - `prNumber` is the GitHub Pull Request number
      - `headBranch` is the head branch of the Pull Request

3. Once the Argo CD cluster `Secret` is created with the necessary `metadata.labels`, it, along with the properly labeled Pull Request, trigger the second Argo CD `ApplicationSet` that uses the Matrix generator to merge the template parameters from the Pull Request and Cluster generators to generate an `Application` that will deploy the PR preview application into the PR vCluster.
4. The `vcluster-ready-labeler` `Deployment` executes a simple shell script every 10 seconds that adds a label to `VirtualClusterInstance` resources when their `VirtualClusterOnline` status becomes `True`. This in turn is added by vCluster Platform to the Argo CD cluster `Secret` and is the last label required to trigger the second PR preview app `ApplicationSet` with the Cluster generator. Although not absolutely necessary, this setup ensures there are no initial errors with the second generated`Application` as it tries to connect to the PR vCluster that is not yet ready.
5. Additional commits to the Pull Request head branch will automatically be redeployed to the PR vCluster via the second `Application`, deploying the updated container image with a tag based on the short commit sha of the triggering PR commit. However, the vCluster `Application` is associated with the PR head branch, and not a specific commit, so it does not get recreated with every PR commit.
6. If the Pull Request is merged or closed, or if the `create-pr-vcluster-external-argocd` label is removed, both `Applications` will be deleted resulting in the PR vCluster being deleted.

> [!NOTE]
> The Argo CD `ApplicationSet` that creates the vCluster instance **does not** have to be deployed to an Argo CD instance that has been integrated with a vCluster Platform Project. However, the Argo CD instance where this ApplicationSet is added, does require the permission to create Kubernetes resources in the Kubernetes cluster where the vCluster Platform is installed - more specifically, it must be able to create the `VirtualClusterInstance` resources in a vCluster Platform Project `Namespace`. For this example, the `VirtualClusterInstance` will be created in the `p-auth-core` namespace which corresponds to the *Auth Core* Project and is the `metadata.namespace` value of the [example `VirtualClusterInstance` CRD](./kustomize/vcluster.yaml).
>
> The second Argo CD `ApplicationSet` must be applied to the same Argo CD instance that is integrated with the vCluster Platform Project where the Pull Request `VirtualClusterInstance` is created, as that resulting vCluster must be available as the destination cluster for the example application that is deployed by the Argo CD `Application` generated by this `ApplicationSet`. This Argo CD instance could be the same as the one used for the first `ApplicationSet`, but it could also be a different Argo CD instance; just as long as it has been integrated with the vCluster Platform Project where the Pull Request vCluster is created.

### Sleep Mode

Sleep mode is enabled for the PR vCluster to prevent long-running pull requests from consuming unnecessary resources. It also allows developers to pause and resume debugging sessions without incurring ongoing infrastructure costs — the vCluster remains dormant until it’s explicitly reactivated to troubleshoot problematic changes. To avoid unintentionally waking the vCluster during routine health checks, the vCluster is configured to ignore requests from the `argo*` user agent to its Kubernetes API server. This prevents Argo CD’s cluster polling from keeping the vCluster perpetually online, preserving the benefits of sleep mode. However, it also means another mechanism is required to wake the vCluster when a relevant update occurs — specifically, when a new commit is pushed to the PR head branch. In this setup, an [Argo CD Notification is configured](./manifests/argocd-notifications-cm.yaml) to send an HTTP POST to the vCluster’s Kubernetes API server whenever such a commit is detected. The request includes a custom user agent (`vcluster-wakeup` that is not ignored by the sleep mode proxy), which triggers the vCluster Platform to wake the vCluster so Argo CD can synchronize the latest application state and deploy pull request updates to the PR vCluster.

### Components

- vCluster Platform: leverages the `VirtualClusterInstance` CRD - [vcluster.yaml](./kustomize/vcluster.yaml), `VirtualClusterTemplate` CRD - the [Default Virtual Cluster Template](../../virtual-cluster-templates/vcluster-templates.yaml#L30), and `Project` CRD - [projects.yaml](../../projects/projects.yaml#L70-L131)
- vCluster instances: the `VirtualClusterInstance` created via the Argo CD Application generated by this Application Set triggers the creation of a vCluster instance that is managed by the vCluster Platform and automatically added to Argo CD (by utilizing the `loft.sh/import-argocd` label) as an available Kubernetes cluster destination for deployments.
- Argo CD: One Argo CD instance is used in this example, and it is deployed to the same Kubernetes cluster where the vCluster Platform is deployed. The Argo CD instance is also [integrated with the *Auth Core* vCluster Platform Project](../../projects/projects.yaml#L120-L131). The example leverages [Argo CD ApplicationSets}(https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/) that use the [Pull Request Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Pull-Request/) and the [Cluster Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/) to dynamically generate an Argo CD Application to deploy the demo application to the dynamic and ephemeral vCluster for any repository Pull Requests with the `create-pr-vcluster-external-argocd` label.
  
#### Argo CD ApplicationSets

- **Pull Request Generator based ApplicationSet** ([pr-vcluster-external-argocd.yaml](./apps/pr-vcluster-external-argocd.yaml)) creates the vCluster instances via a Kustomize app that is automatically added as a server to an Argo CD instances that is intergrated with a vCluster Platform Project
  - A Pull Request label, `create-pr-vcluster-external-argocd` is used to filter Pull Requests and make the ephermeral preview environment opt in, instead of created for every repostiory pull request. This is optional.
  - **Kustomize App:** A Kustomize app is used to create the `VirtualClusterInstance` so that the *Pull Request Generator based ApplicationSet* may add dynamic labels that will then be applied to the Argo CD cluster `Secret` via the vCluster Platform integration, and eventually utilized by the *Cluster Generator based ApplicationSet*.
    - The `VirtualClusterInstance` includes the `metadata.label` `loft.sh/import-argocd: 'true'` that will trigger the vCluster Platform to automatically add the vCluster to the Argo CD instance that is configured with the vCluster Platform Project where the vCluster is created - in this example, that is the `auth-core` project. Also note that the `VirtualClusterInstance` uses a Virtual Cluster template per the `spec.templateRef` object. The `default-template` specified could have been configured to auto-add to Argo CD, by setting the `label` previously mentioned, that setting does not need to be enabled on the template. Additional `labels` are added dynamically with the Argo CD Pull Request Generator as described below.
  - The Pull Request Generator dynamic labels include:
    - `vclusterName`: Used to create a reference to this `VirtualClusterInstance` as the `server` URL value
    - `repo`: the repository for the GitHub Pull Request and the application code that needs to be deployed by Argo CD
    - `pr`: Set to 'true' and used as a filter for the *Cluster Generator based ApplicationSet* so that only Pull Request ephemeral vCluster instances will trigger the generate of an Argo CD `Application` to deploy the Pull Request association application
    - `headBranch`: The head branch of the Pull Request. This is used to pull the correct container image (from the GitHub Container Registry for this example) associated with the Pull Request. The head branch is used insteat of the commit sha because the Pull Request vCluster will not be recreated for any new commits to the head branch of the Pull Request but the commits to the head branch will trigger a new container image build and a redeployment by Argo CD. The `headBranch` is also used as the `targetRevision` value for the *Cluster Generator based ApplicationSet* described below.
    - `targetRevision`: The commit SHA of the Pull Request head branch to target for the generated Argo CD `Application`
    - `headShortSha`: The short, 8 character, version of the commit SHA of the Pull Request head branch. This is only used in the output of the example app.
- **Cluster Generator based ApplicationSet** ([pr-preview-app-cluster-operator.yaml](./apps/pr-preview-app-cluster-operator.yaml)) uses labels, dynamically added to the `VirtualClusterInstance` created with the Pull Request Generator based ApplicationSet, to deploy the actual application code associated with the head commit of the Pull Request (in this example it is a [Helm based application](../../../helm-chart/)

Ideal PR-preview workflow for vCluster with sleep mode.

✅ Matrix generator using PR x Cluster
✅ Label-based cluster filtering (only deploy to matching vCluster)
✅ Argo CD Notification subscription for wake-up only when OutOfSync (new commit to PR head branch)
✅ Non-intrusive wake-up trigger (via subscribe.*)
✅ Precise per-vCluster labeling for webhook templating (vclusterName, vclusterProjectId)
✅ TLS + ingress config per preview
✅ Retries and self-heal enabled for robustness
✅ Namespace auto-creation via sync option

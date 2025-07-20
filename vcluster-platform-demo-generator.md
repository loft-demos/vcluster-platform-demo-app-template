# vCluster Platform Demo Generator

![Supports vCluster Inception](https://img.shields.io/badge/vCluster-Inception%20Ready-blueviolet?style=flat-square&logo=kubernetes)

> _Self-service, ephemeral, and powered by vCluster inception — for fast and flexible vCluster and vCluster Platform demo environments._

---

## What It Is (and What It’s Not)

The **vCluster Platform Demo Generator** is a specially configured vCluster Platform that runs in a vCluster and is used to create dynamically customized vCluster Platform demo environments that themselves run in child vCluster instances - often referred to as vCluster inception.

The **vCluster Platform Demo Generator's** main purpose is not to showcase vCluster inception. Sure, running a vCluster inside a vCluster inside a vCluster is cool — however, the core purpose of the **vCluster Platform Demo Generator** is to provide easy to create vCluster Platform (and vCluster) demo environments that cover the majority of common customer-centric use cases. Running the **vCluster Platform Demo Generator** vCluster Platform in a vCluster allows installing applications without effecting its host GKE cluster directly and is [easy to manage and repeatable via GitOps](https://github.com/loft-demos/loft-demo-base/tree/main/vcluster-platform-demo-generator).

The **vCluster Platform Demo Generator** provides a flexible and cost-efficient way to provision **ephemeral**, **self-service** demo environments that can be used to showcase both:

- **vCluster Platform** features (Projects, Templates, SSO, integrations, etc.)
- **Standalone vCluster** capabilities (control plane isolation, multi-tenancy, integrations)

Whether you're part of LoftLabs or just a vCluster power user, the **vCluster Platform Demo Generator** streamlines and scales demo creation — with or without vCluster inception.

---

## Deployment Modes

| Deployment Style       | Description                                                                 |
|------------------------|-----------------------------------------------------------------------------|
| **Managed Mode**       | The vCluster Platform demo vCluster runs inside a vCluster managed by [another vCluster Platform - itself managed with GitOps](https://github.com/loft-demos/loft-demo-base/tree/main/vcluster-platform-demo-generator), that runs in another vCluster Platform running on GKE.  Demo environments, with vCluster Platform and use case examples pre-installed, are created as child vCluster instances (vCluster inception) |
| **Self-managed Mode**  | Deploy and configure the vCluster Platform yourself directly on a self-managed host cluster and [follow the self-managed instructions](./self-managed-demo-cluster/README.md).  |

> **vCluster inception is completely optional.** You can bring your own cluster and skip the nesting — it just takes a little more setup (e.g., Crossplane, Argo CD, secrets).

### Managed Mode (vCluster Inception)

The **vCluster Platform Demo Generator** managed mode includes the following features that will need to be manually configured in the self-managed mode:

- vCluster Platform non-trial license - integrated via a _Project Secret_ in the Demo Generator parent vCluster Platform
- Ingess Nginx ingress controller integrated with a wildcard domain and HTTPS certificate deployed to host cluster (actually two levels up); the domain for a generated vCluster Platform Demo environment is based on the name of the vCluster appended to this wildcard sub-domain
- Crossplane based creation of a copy of this template repository based on the vCluster name that is also automatically deleted from GitHub when the generated vCluster Platform Demo environment is deleted - and because we are using vCluster inception, Crossplane is installed in the **vCluster Platform Demo Generator** vCluster
- A dynamically generated vCluster Platform Access Key that will be _injected_ (via a Project Secret) in every generated demo environment and integrated with Argo CD Notifications
- Argo CD installed via a vCluster Platform App that is part of the _vCluster Platform Demo_ virtual cluster template, along with Crossplane creation of GitHub webhooks for the generated repository (copy of this repository)
- Crossplane installed via a vCluster Platform App that is part of the _vCluster Platform Demo_ virtual cluster template (used to create GitHub webhooks and configure repo level GitHub Actions secrete and environment variables)
- A dynamically generated Argo CD cluster `Secret` that controls what vCluster use case examples get installed into the vCluster Platform Demo environment

### Secrets Management for vCluster Platform Demo Generator

Many secrets are _injected_ from the parent vCluster Platform environment using `ProjectSecrets`. Although `ProjectSecrets` are typically used to generate regular Kubernetes `Secrets`, they may also be used to create new `ProjectSecrets` for a vCluster Platform running inside a child (inception) vCluster. Secrets used by the vCluster Platform child demo vCluster instances include:

- `ghcr-login-secret`: Used to pull private container images from **loft-demos** Org private GitHub Container Registries.
- `loft-demo-org-cred`: A GitHub App credential used to create demo repositories and webhooks with Crossplane and for use with Argo CD to have on-demand GitHub updates for Argo CD `Applications`.

```yaml
apiVersion: management.loft.sh/v1
kind: ProjectSecret
metadata:
  labels:
    loft.sh/sharedsecret-name: ghcr-login-secret
    loft.sh/sharedsecret-namespace: vcluster-platform
  name: ghcr-login-secret
  namespace: p-auth-core
spec:
  displayName: ghcr-login-secret
```

---

## Why This Exists

- Allows for easy self-management of disposable demo environments - to include all necessary supporting applications
- Make vCluster and vCluster Platform demos **fast**, **repeatable**, and **ephemeral**
- Automatically clean up resources like GitHub repositories
- Showcase how **real workloads** can run in a vCluster — including Argo CD, Crossplane, External Secrets Operator, Kyverno, Rancher, and more (vCluster is a certified Kubernetes distribution)

---

## Architecture

Inception Mode uses a **Demo Generator vCluster**, itself running in a host cluster with vCluster Platform installed and configured with the necessary templates and _Project Secrets_ to create one or more **Demo Generator vCluster** instances.

You can also deploy this Demo Generator on any Kubernetes cluster, with or without the vCluster Platform.

### Demo Generator includes

- vCluster Platform
- Argo CD (App of Apps)
- Crossplane (GitHub + Kubernetes Providers)
- GitHub repo for GitOps:  
  [`loft-demos/vcluster-platform-demo-generator`](https://github.com/loft-demos/loft-demo-base/tree/main/vcluster-platform-demo-generator)

Each generated demo environment is:

- A vCluster provisioned via a `VirtualClusterTemplate` provisioned as part of the **Demo Generator vCluster** vCluster Platform via GitOps
- The `VirtualClusterTemplate` includes the Argo CD and Crossplane bootstrap vCluster Platform Apps (Platform packaged applications and scripts that may be included as part of a `VirtualClusterTemplate`)
- Backed by a dedicated GitHub repo created via Crossplane from  
  [`vcluster-platform-demo-app-template`](https://github.com/loft-demos/vcluster-platform-demo-app-template)

---

## Tools Used

- [vCluster Platform](https://www.vcluster.com/docs/platform/next/)
- [vCluster OSS](https://www.vcluster.com/)
- [Crossplane](https://crossplane.io/)
- [Argo CD](https://argo-cd.readthedocs.io/)
- [Flux](https://fluxcd.io/) (optional)

---

## Features

- GitOps-based provisioning and teardown
- GitHub repo templating per demo
- Argo CD + Crossplane integration
- Optional External Secrets Operator support
- Demo environment scoping via vCluster Platform Projects and Templates



### Use Cases

- Custom Resource Sync with Postgres Operator
- Database Connector with fully managed MySQL Operator install
- Resolve DNS
- Kyverno policies & Central Admission Control  
- External Secrets Operator integration
- vNode Integration with vCluster
- Virtual Schedulers
- Argo CD Add-ons for vCluster
- Flux integration for vCluster
- Dynamic Pull Request Environments with vCluster and Argo CD

---

## In Progress / Wishlist

### Improvements

- Replace secret hacks with [External Secrets Operator](https://external-secrets.io/)
- Add a second host/connected cluster (currently must be done manually)

---

## FAQs

### Can I use this without running a vCluster inside a vCluster?

Yes! Bring your own cluster and deploy the necessary _bootstrap apps_ - Argo CD, Crossplane.

### Is this just for vCluster Platform demos?

No — it works equally well for standalone vCluster demos too.

### Do all vCluster Platform features work in nested setups?

Not all. Known limitations:

- Ingress-based wakeup doesn’t currently work in nested vClusters.
- Central Admission Control works only if policy engines (e.g., Kyverno) run in the child vCluster.

---

## Contributing

This project is maintained by the team at LoftLabs. Feel free to open issues, suggest improvements, or create a copy and adapt for your own demos!

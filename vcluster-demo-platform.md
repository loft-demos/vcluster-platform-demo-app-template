# vCluster Demo Platform

![Supports vCluster Inception](https://img.shields.io/badge/vCluster-Inception%20Ready-blueviolet?style=flat-square&logo=kubernetes)

> _Self-service, ephemeral, and powered by vCluster inception — for fast and flexible vCluster and vCluster Platform demo environments._

---

## What It Is (and What It’s Not)

The **vCluster Demo Platform's** main purpose is not to showcase vCluster inception. Sure, running a vCluster inside a vCluster inside a vCluster is cool — however, the core purpose of the **vCluster Demo Platform** is to provide easy to create vCluster Platform (and vCluster) demo environments that cover the majority of common customer-centric use cases.

The **vCluster Demo Platform** provides a flexible and cost-efficient way to provision **ephemeral**, **self-service** demo environments that can be used to showcase both:

- **vCluster Platform** features (Projects, Templates, SSO, CRDs, etc.)
- **Standalone vCluster** capabilities (control plane isolation, multi-tenancy, integrations)

Whether you're part of LoftLabs or just a vCluster power user, this platform streamlines and scales demo creation — with or without vCluster inception.

---

## Deployment Modes

| Deployment Style    | Description                                                                 |
|---------------------|-----------------------------------------------------------------------------|
| **Managed Mode**      | Demo Generator runs inside a vCluster managed by another vCluster Platform.  Demo environments are created as child vCluster instances (vCluster inception) |
| **Self-managed Mode** | Deploy and configure the vCluster Platform yourself directly on a self-managed host cluster.  |

> **vCluster inception is completely optional.** You can bring your own cluster and skip the nesting — it just takes a little more setup (e.g., Crossplane, Argo CD, secrets).

### Managed Mode (vCluster Inception)

The **vCluster Demo Platform** managed mode includes the following features that will need to be manually configured in the self-managed mode:

- vCluster Platform non-trial license - integrated via a _Project Secret_ in the Demo Generator parent vCluster Platform
- Ingess Nginx ingress controller integrated with a wildcard domain and HTTPS certificate; the domain for a generated vCluster Demo environment is based on the name of the vCluster
- A static vCluster Platform Access Key that will be _injected_ (via a Project Secret) in every generated demo environment and integrated with Argo CD Notifications
- Argo CD installed via a vCluster Platform App that is part of the _vCluster Platform Demo_ virtual cluster template
- Crossplane installed via a vCluster Platform App that is part of the _vCluster Platform Demo_ virtual cluster template

---

## Why This Exists

- Make vCluster and vCluster Platform demos **fast**, **repeatable**, and **ephemeral**
- Automatically clean up resources like GitHub repositories
- Showcase how **real workloads** can run in a vCluster — including Argo CD, Crossplane, and more

---

## Architecture

Inception Mode uses a **Demo Generator vCluster**, itself running in a host cluster with vCluster Platform installed and configured with the necessary templates and _Project Secrets_ to create one or more **Demo Generator vCluster** instances.

You can also deploy this Demo Generator on any Kubernetes cluster, with or without the vCluster Platform.

### Demo Generator includes:

- vCluster Platform
- Argo CD (App of Apps)
- Crossplane (GitHub + Kubernetes Providers)
- GitHub repo for GitOps:  
  [`loft-demos/loft-demo-base`](https://github.com/loft-demos/loft-demo-base/tree/main/vcluster-platform-demo-generator)

Each generated demo environment is:

- A vCluster provisioned via a `VirtualClusterTemplate` provisioned as part of the **Demo Generator vCluster** vCluster Platform via GitOps
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

---

## In Progress / Wishlist

### Improvements

- Replace secret hacks with [External Secrets Operator](https://external-secrets.io/)
  - Label secrets with: `loft.sh/project-secret: 'true'`
- Add a second host/connected cluster
- Improve Rancher demo

### Use Cases

- External Secrets Operator integration  
- DNS resolution in vCluster  
- Operator-based app install  
- Kyverno policies & Central Admission Control  
- External Secrets Operator integration

---

## ❓ FAQs

### Can I use this without running a vCluster inside a vCluster?

Yes! Bring your own cluster and deploy the Demo Generator directly.

### Is this just for vCluster Platform demos?

No — it works equally well for standalone vCluster demos too.

### Do all vCluster Platform features work in nested setups?

Not all. Known limitations:

- Ingress-based wakeup doesn’t currently work in nested vClusters.
- Central Admission Control works only if policy engines (e.g., Kyverno) run in the child vCluster.

---

## Contributing

This project is maintained by the team at LoftLabs. Feel free to open issues, suggest improvements, or fork and adapt for your own demos!

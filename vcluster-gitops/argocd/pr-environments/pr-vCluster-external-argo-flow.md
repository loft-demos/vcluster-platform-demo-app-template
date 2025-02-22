# PR vCluster with Shared Argo CD Flow

```mermaid
---
config:
  look: classic
---
flowchart TD
    A["GitHub Repo"] -->| Create | B["Pull Request"] -->| Labeled | L[create-pr-vcluster-external-argocd] 
    L -->| Triggers | C["Argo CD PR vCluster AppSet"]
    C -->| Creates | V["PR vCluster"]
    V --> | Triggers |CS["Argo CD Cluster Secret"]
    L --> | Triggers |AS["Argo CD Preview App AppSet"]
    CS --> | Triggers |AS["Argo CD Preview App AppSet"]
    AS --> MP["Pull Request Generator"]
    AS --> MC["Clusters Generator"]
    MP --> MG["Merge Generator"]
    MC --> MG["Merge Generator"]
    MG -->| Creates | APP["Preview Helm App"]
    APP --> | Deployed | V
```

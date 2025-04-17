# vCluster Platform Environments Todos

- Flux - Auto create Flux GitHub `Receiver` webhook with Crossplane
  - The GitHub pull request Flux `Receiver` [definition](vcluster-gitops/argocd/flux/pull-request-environments/pr-github-receiver.yaml)
  - The path format is `/hook/sha256sum(token+name+namespace)`; see https://fluxcd.io/flux/components/notification/receivers/#webhook-path
  - The Flux Receiver `Ingress` [definition](vcluster-gitops/argocd/flux/manifests/flux-notification-ingress.yaml)

- Using Multus with vCluster

- Better custom resource sync examples

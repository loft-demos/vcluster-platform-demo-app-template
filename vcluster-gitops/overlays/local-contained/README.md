# Local-Contained Overlay

This is the `vind` GitOps overlay.

Use it when Git is hosted in Forgejo or another Gitea-compatible service
instead of GitHub.

What it changes:

- provides the root Argo CD app at [root-application.yaml](./root-application.yaml)
- points the app-of-apps bootstrap at the local-contained app-of-apps overlay
- switches the PR-oriented Argo CD generators to `gitea`
- uses generic Git and image placeholders:
  - `{REPLACE_GIT_BASE_URL}`
  - `{REPLACE_IMAGE_REPOSITORY_PREFIX}`
- removes GitHub-specific PR notification/comment behavior from this path
- adds a small Forgejo PR webhook adapter in `argocd` that normalizes the
  Forgejo payload before forwarding it to the Argo CD ApplicationSet webhook
  endpoint

Current limits:

- Gitea PR generators do not support the same label filtering as GitHub
- Crossplane GitHub provider flows are still GitHub-shaped
- some image flows outside the overlay still assume GHCR

Why the adapter exists:

- Forgejo PR webhook payloads in this setup include `repository.created_at` as
  an RFC3339 string
- the Argo CD ApplicationSet webhook parser used here rejects that field shape
  when sent directly
- the adapter rewrites only the field that breaks decoding, then forwards the
  request to `argocd-applicationset-controller`
- if Argo CD or Forgejo behavior changes in a future upgrade, re-test direct
  delivery before removing this adapter

For the actual bootstrap flow, start with:

- [vind-demo-cluster/README.md](../../../vind-demo-cluster/README.md)

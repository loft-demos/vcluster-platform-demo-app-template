# Local-Contained Overlay

This is the `vind` GitOps overlay.

Use it when Git is hosted in Forgejo or another Gitea-compatible service
instead of GitHub.

What it changes:

- provides the root Argo CD app at [root-application.yaml](./root-application.yaml)
- points the app-of-apps bootstrap at the local-contained app-of-apps overlay
- switches the PR-oriented Argo CD generators to `gitea`
- uses generic Git and image placeholders:
  - `http://forgejo-http.forgejo.svc.cluster.local:3000`
  - `forgejo.vcp.local/vcluster-demos/vcp-gitops`
- removes GitHub-specific PR notification/comment behavior from this path

Current limits:

- Gitea PR generators do not support the same label filtering as GitHub
- Crossplane GitHub provider flows are still GitHub-shaped
- some image flows outside the overlay still assume GHCR

For the actual bootstrap flow, start with:

- [vind-demo-cluster/README.md](../../../vind-demo-cluster/README.md)

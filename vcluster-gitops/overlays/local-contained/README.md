# Local-Contained Overlay

This overlay is the first-pass `local-contained` mode for running this repo
against an embedded Forgejo or another Gitea-compatible Git service inside a
`vind` management cluster.

This is the default target pattern for `vind`, even though it is not fully
completed yet.

It intentionally changes only the pull request driven Argo CD flows. The
default GitHub-oriented manifests remain unchanged in the base directories.

## What This Overlay Changes

- points the root app-of-apps bootstrap at a local-contained app-of-apps overlay
- converts the `argo-cd-pr-application-set` `App` from `github` to `gitea`
- converts the repo preview `ApplicationSet` from `github` to `gitea`
- routes the pull request environment bootstrap `Application` to a local-contained
  overlay under the use-case directory
- removes GitHub-specific Argo CD notification subscriptions from the
  local-contained PR flows

## Required Placeholders

- `{REPLACE_GIT_BASE_URL}`
  Example: `https://forgejo.demo.example.com`
- `{REPLACE_IMAGE_REPOSITORY_PREFIX}`
  Example: `forgejo.demo.example.com/loft-demos`

## Important Limitations

- Argo CD's Gitea pull request generator does not support label filtering, so
  this first pass watches all open pull requests in the configured repository.
- GitHub commit status updates and pull request comments are disabled in this
  mode.
- Crossplane GitHub provider, GHCR-oriented flows, and other GitHub-specific
  use cases are not converted by this overlay.
- Use polling for the first pass. Argo CD already polls Git repositories even
  without webhooks.

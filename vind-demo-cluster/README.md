# vind Demo Cluster

This folder is the starting point for running this repo against a
self-hosted, self-contained demo environment built on
[`vind`](https://www.vcluster.com/docs/vcluster/deploy/control-plane/docker-container/basics).

The intended model is:

1. start a `vind` cluster
2. install Argo CD, External Secrets Operator, and vCluster Platform directly from the `vind`
   `vcluster.yaml`
3. bootstrap secrets from 1Password through ESO
4. let Argo CD install `vcluster-gitops/` and selected use cases

This replaces the secret projection and bootstrap behavior normally supplied by
the [vCluster Platform Demo Generator](https://github.com/loft-demos/loft-demo-base/blob/main/vcluster-platform-demo-generator/README.md).

## Default Pattern

The default target pattern for `vind` in this repo is now:

- local-contained Git hosting with Forgejo
- local polling and Gitea-compatible Argo CD generators
- local hostnames on OrbStack
- no required public domain

The public GitHub-backed path still exists, but it should be treated as the
fallback when you specifically need GitHub webhooks or public demo URLs.

## Bootstrap Style

The default entrypoint for the self-contained `vind` path is the comprehensive
helper script:

- it creates the `vind` cluster
- it installs vCluster Platform, Argo CD, ESO, and Forgejo
- it runs the local placeholder replacement
- it starts the OrbStack adapter
- it bootstraps the local repo into Forgejo

The lower-level helper scripts still exist for troubleshooting and partial
reruns.

## Why This Path Exists

The Demo Generator path works well for centrally managed demo environments, but
it couples this repo to generated secrets and pre-installed components such as
Argo CD, Crossplane, and other bootstrap applications.

For a self-hosted demo running on `vind`, the main goals are:

- no dependency on the Demo Generator
- deterministic bootstrap for coworkers
- reuse of the existing GitOps and use-case content in this repo
- minimal manual secret handling

## Bootstrap Assumptions

This bootstrap path assumes:

- Argo CD is installed by [`vcluster.yaml`](./vcluster.yaml)
- ESO is installed by [`vcluster.yaml`](./vcluster.yaml)
- vCluster Platform is installed by [`vcluster.yaml`](./vcluster.yaml)
- a coworker performing the setup has access to 1Password and can create the
  initial ESO service-account token secret
- a coworker performing the setup has a valid vCluster Platform license token

The local [`vcluster.yaml`](./vcluster.yaml) is tuned for this repo. It:

- is intended to be applied with vCluster CLI `0.32.1`
- starts `vind` with the default standalone backing store and Kubernetes `v1.35.1`
- installs Argo CD from the current `argo-cd` Helm chart release
- installs ESO from the current `external-secrets` Helm chart release
- installs vCluster Platform from chart version `4.7.1` by default
- creates the namespaces and Argo CD cluster secret this repo expects
- creates a dedicated `LoadBalancer` service for the vCluster Platform UI/API
- enables only the `eso` app-of-apps label by default so the initial bootstrap
  stays small
- exposes Argo CD as a `LoadBalancer` service for local access in `vind`
- installs Forgejo for the self-contained Git and registry path

## Files In This Folder

- [`vcluster.yaml`](./vcluster.yaml)
  template for starting the `vind` management cluster with Argo CD, ESO,
  vCluster Platform, and the initial in-cluster Argo CD cluster secret
- [`eso-cluster-store.yaml`](./eso-cluster-store.yaml)
  defines a 1Password-backed ESO `ClusterSecretStore` for the `vind` cluster
- [`bootstrap-external-secrets.yaml`](./bootstrap-external-secrets.yaml)
  defines the initial management-cluster `ExternalSecret` resources that
  materialize the first set of repo, image, notification, and Crossplane
  credentials
- [`install-vind.sh`](./install-vind.sh)
  helper for creating or upgrading the local `vind` cluster, including
  rendering the vCluster Platform license token, version, and host into
  `vcluster.yaml`
- [`start-orbstack-domains.sh`](./start-orbstack-domains.sh)
  helper for discovering the current `vind` service upstreams and starting the
  OrbStack local-domain adapter
- [`delete-vind.sh`](./delete-vind.sh)
  helper for stopping the OrbStack local-domain adapter before deleting the
  `vind` cluster
- [`bootstrap-self-contained.sh`](./bootstrap-self-contained.sh)
  experimental all-in-one helper for the self-contained path
- [`cloudflare-tunnel.yaml`](./cloudflare-tunnel.yaml)
  provides a named-tunnel `cloudflared` template for exposing Argo CD and
  vCluster Platform through Cloudflare Tunnel
- [`orbstack-domains/`](./orbstack-domains)
  provides an OrbStack-specific Caddy proxy setup for mapping local `vind`
  endpoints to a default `vcp.local` local domain set, with easy overrides for
  custom domains

## Bootstrap Sequence

1. Clone this repo directly.
2. Run the comprehensive bootstrap helper:

   ```bash
   LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
     --repo-name your-demo-repo \
     --org-name your-org
   ```

   Default behavior:
   - `--base-domain` defaults to `vcp.local`
   - `--control-plane-nodes` defaults to `1`
   - `--worker-nodes` defaults to `2`
   - the control plane node is tainted `node-role.kubernetes.io/control-plane=:NoSchedule`
   - Forgejo defaults to <https://forgejo.vcp.local>
   - Forgejo admin defaults to `demo-admin` / `vcluster-demo-admin`
   - the repo is renamed locally before it is pushed into Forgejo
   - the Forgejo repo owner defaults to the Forgejo admin user

3. Open the local endpoints:
   - <https://vcp.local>
   - <https://argocd.vcp.local>
   - <https://forgejo.vcp.local>

4. Create the bootstrap secret `one-password-sa-token` in the `eso` namespace.
5. Apply [`eso-cluster-store.yaml`](./eso-cluster-store.yaml).
6. Apply [`bootstrap-external-secrets.yaml`](./bootstrap-external-secrets.yaml).
7. Verify that the initial bootstrap secrets reconcile in:
   - `argocd`
   - `vcluster-platform`
   - `crossplane-system`
8. Verify that the comprehensive bootstrap applied the Argo CD root application:
   - [`vcluster-gitops/overlays/local-contained/root-application.yaml`](../vcluster-gitops/overlays/local-contained/root-application.yaml)
9. Enable additional use cases only after the base secret contract is working.

### Teardown

Use the delete helper instead of calling `vcluster delete` directly:

```bash
bash vind-demo-cluster/delete-vind.sh
```

That tears down the per-cluster OrbStack/Caddy adapter first, then deletes the
`vind` cluster. Without that step, `vcluster delete <name>` can leave the
`vcluster.<name>` Docker network in use by the adapter container.

If you installed with a custom host such as `--vcp-host team-a.vcp.local`, the
delete helper will reuse the generated OrbStack env file automatically as long
as it still exists. If you removed that env file or used a custom env-file
path, pass the same host or env-file override to `delete-vind.sh`.

### Lower-Level Helpers

The comprehensive helper is the default path. These lower-level helpers remain
available for troubleshooting and partial reruns:

```bash
bash vind-demo-cluster/install-vind.sh
bash vind-demo-cluster/start-orbstack-domains.sh
bash vind-demo-cluster/delete-vind.sh
```

## Repo Initialization for Self-Contained `vind`

For the self-contained `vind` path, you do not need to create a GitHub template
copy just to make the repo usable.

Recommended approach:

1. clone this repo directly
2. run the local replacement script
3. if using Forgejo, bootstrap the repo into Forgejo after replacement

This is the self-contained alternative to the GitHub template-copy workflow.
It replaces the placeholder-renaming part of
[`replace-text.yaml`](../.github/workflows/replace-text.yaml) locally, but it
does not create or rename a GitHub repo for you.

The local replacement script is:

```bash
bash scripts/replace-text-local.sh \
  --repo-name your-demo-repo \
  --org-name your-org \
  --include-md
```

If you omit `--base-domain`, it defaults to `VCP_HOST` or `vcp.local`.

This mirrors the main placeholder replacement behavior from
[`.github/workflows/replace-text.yaml`](../.github/workflows/replace-text.yaml)
for local use.

Use the GitHub template-copy + GitHub Actions path only when you are following
the GitHub-backed workflow and want the managed repo initialization behavior.

If you later want a remote repo for the self-contained path, do that after the
local replacement step:

1. create a repo in Forgejo or GitHub
2. push the already-customized local clone

The `vcluster.yaml` intentionally does not bootstrap this repo's root Argo CD
`Application`, because `vcluster-gitops/` depends on vCluster Platform CRDs
that are not present until Platform is installed.

### OrbStack Domain Note

If you create `vind` with:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/install-vind.sh
```

The default cluster shape is `1` control plane node and `2` worker nodes. You
can override the worker count, for example:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/install-vind.sh \
  --worker-nodes 3
```

OrbStack will usually expose the control plane container at a domain like:

```text
https://vcluster.cp.vcp.orb.local
```

That domain is useful as the raw control plane container endpoint, but it is
not the best default hostname for Argo CD or the vCluster Platform UI.

For this repo, treat it like this:

- `vcluster.cp.vcp.orb.local`
  the raw OrbStack control plane container domain created by `vind`
- `*.lb....orb.local`
  raw OrbStack-generated load balancer domains for Kubernetes `LoadBalancer`
  services inside `vind`
- `vcp.local`, `argocd.vcp.local`, `forgejo.vcp.local`
  the friendly operator-facing domains we want to use for the self-contained
  demo flow

The OrbStack local-domain adapter under
[`orbstack-domains/`](./orbstack-domains) exists to bridge those friendly
domains to the actual `vind` service upstreams.

## Forgejo

Forgejo is part of the default self-contained `vind` path. In this mode:

- Git is hosted inside the `vind` cluster
- OCI images can be pushed to the Forgejo package registry
- Argo CD can use polling or Gitea-compatible generators instead of
  GitHub-specific webhooks

The first pass of that overlay exists at
[`vcluster-gitops/overlays/local-contained`](../vcluster-gitops/overlays/local-contained/README.md).
It converts the Argo CD pull request generators to `gitea`, switches the PR
flows to generic Git and image registry placeholders, and removes
GitHub-specific notification hooks from the local-contained PR path.

The default Forgejo bootstrap path uses the demo admin credentials created by
[`install-vind.sh`](./install-vind.sh) and
[`bootstrap-self-contained.sh`](./bootstrap-self-contained.sh):

```bash
bash scripts/bootstrap-forgejo-repo.sh \
  --forgejo-url https://forgejo.vcp.local \
  --username demo-admin \
  --password "$FORGEJO_ADMIN_PASSWORD" \
  --owner demo-admin \
  --owner-type user \
  --repo vcluster-platform-demo-app-template
```

That script creates the target repo through the Forgejo API if needed, then
pushes the current local branches and tags into Forgejo.

## OrbStack Local Domains

For SE laptops running `vind` on OrbStack, the default local hostname pattern
is:

- `vcp.local`
- `argocd.vcp.local`
- `forgejo.vcp.local`

This should be treated as the default, not the only option. The setup is
designed so you can override the hostnames easily per environment.

Do not try to use the OrbStack Kubernetes `*.k8s.orb.local` path for `vind`.
That path is for OrbStack's own Kubernetes integration, while `vind` is a
Docker-backed management cluster. For `vind`, the better OrbStack-specific
pattern is:

1. expose the relevant services from `vind` with `LoadBalancer` services
2. attach the OrbStack domain proxy container to the dedicated `vind` Docker
   network, which is normally `vcluster.<cluster-name>`
3. identify the local upstream address for each service
4. run a tiny OrbStack container with custom domains that reverse proxies to
   those upstreams

This repo includes a ready-to-adapt setup in
[`orbstack-domains/`](./orbstack-domains):

- [`compose.yaml`](./orbstack-domains/compose.yaml)
- [`Caddyfile`](./orbstack-domains/Caddyfile)
- [`.env.example`](./orbstack-domains/.env.example)

### OrbStack Setup

Both self-contained install methods start the OrbStack adapter
automatically by default:

- [`install-vind.sh`](./install-vind.sh)
- [`bootstrap-self-contained.sh`](./bootstrap-self-contained.sh)

For manual reconfiguration, reruns, or troubleshooting, use
[`start-orbstack-domains.sh`](./start-orbstack-domains.sh).

1. Choose your local hostnames.

   Default values:

   ```dotenv
   VIND_DOCKER_NETWORK=vcluster.vcp
   VCP_HOST=vcp.local
   ARGOCD_HOST=argocd.vcp.local
   FORGEJO_HOST=forgejo.vcp.local
   ```

   For multiple `vind` environments, pick unique hostnames per environment. For
   example:

   ```dotenv
   VIND_DOCKER_NETWORK=vcluster.team-a
   VCP_HOST=team-a.vcp.local
   ARGOCD_HOST=argocd.team-a.vcp.local
   FORGEJO_HOST=forgejo.team-a.vcp.local
   ```

   The Docker network should match the `vind` cluster name. For example:

   - cluster `vcp` -> network `vcluster.vcp`
   - cluster `team-a` -> network `vcluster.team-a`

2. Start or rerun the adapter:

   ```bash
   bash vind-demo-cluster/start-orbstack-domains.sh
   ```

   Or with custom hostnames:

   ```bash
   bash vind-demo-cluster/start-orbstack-domains.sh \
     --cluster-name team-a \
     --vcp-host team-a.vcp.local \
     --argocd-host argocd.team-a.vcp.local \
     --forgejo-host forgejo.team-a.vcp.local
   ```

   For the default `vcp` cluster, this writes
   `vind-demo-cluster/orbstack-domains/.env`. For additional clusters, it
   writes per-cluster env files such as
   `vind-demo-cluster/orbstack-domains/.env.team-a`.

   The compose project name is also per cluster, for example
   `vind-local-domains-vcp`.

3. If you need to inspect or override the discovered upstreams, check the
   HAProxy container names created by `vind` for `LoadBalancer` services:

   ```bash
   docker ps --format '{{.Names}}'
   ```

   The helper targets the Docker-network DNS names directly. For the default
   `vcp` cluster, that means:

   - Argo CD: `vcluster.lb.vcp.argocd-server.argocd:443`
   - vCluster Platform: `vcluster.lb.vcp.loft.vcluster-platform:443`

   You can still override them with `--argocd-upstream` and
   `--vcp-upstream`.

   In practice, these upstreams may be:

   - the HAProxy container DNS names on the `vcluster.<cluster-name>` Docker
     network, such as `vcluster.lb.vcp.loft.vcluster-platform:443`
   - a custom override `host:port`

   The preferred path is the HAProxy container DNS names. The point of the
   adapter is to hide those raw upstream names behind stable friendly domains.

4. Open the local domains in your browser:
   - <https://vcp.local>
   - <https://argocd.vcp.local>
   - <https://forgejo.vcp.local>

   Or use your custom values from the helper arguments.

### Upstream Advice

- Argo CD is already configured as a `LoadBalancer` service in
  [`vcluster.yaml`](./vcluster.yaml).
- vCluster Platform is configured through the chart's own `service` values in
  [`vcluster.yaml`](./vcluster.yaml), with `service.type: LoadBalancer`.
- For Forgejo, keep the service local to `vind` and expose it the same way when
  you enable the commented Helm block.
- [`orbstack-domains/compose.yaml`](./orbstack-domains/compose.yaml) joins the
  external Docker network named by `VIND_DOCKER_NETWORK`.

If you change the default local UI hostname, make sure the vCluster Platform
chart is rendered with the same host:

```bash
bash vind-demo-cluster/install-vind.sh \
  --license-token "$TOKEN" \
  --vcp-host team-a.vcp.local \
  --worker-nodes 3
```

That `--vcp-host` value is written into `config.loftHost` for the chart and
should match the Caddy hostname you use in `orbstack-domains/.env`.

This pattern is the easiest OrbStack-specific way to map nice local domains to
`vind` services without requiring a public DNS zone.

## Public GitHub Fallback

For a GitHub-backed demo environment that needs public webhooks and
publicly-accessible URLs, Cloudflare Tunnel is the recommended fallback.

Why this is the best public fallback for this repo:

- it gives you stable public hostnames on a domain you control
- it works well for GitHub webhooks without exposing a home or coworker network
- it is simpler operationally than adding the Tailscale Kubernetes Operator
  just to make a few HTTP endpoints public
- it avoids depending on a vendor-hosted demo domain for DNS and public entry
  points

### Recommendation

Use Cloudflare Tunnel for the GitHub-backed mode when you need public ingress:

- `vcp.{your-domain}` for the vCluster Platform UI and API
- `argocd.{your-domain}` for the shared Argo CD instance

This is a better public option than:

- vCluster Labs hosted domains
  because those are fast to start with but depend on hosted domain plumbing you
  do not control
- Tailscale Operator
  because that is better for private network access than for a simple public
  webhook and demo URL story, and it adds more moving parts and account setup

### Cloudflare Tunnel Setup

1. In Cloudflare, create a named tunnel and public hostnames for:
   - `argocd.{your-domain}`
   - `vcp.{your-domain}`
2. Download the tunnel credentials JSON.
3. Create the Kubernetes secret in the `vind` cluster:

   ```bash
   kubectl create namespace cloudflare-tunnel
   kubectl -n cloudflare-tunnel create secret generic cloudflared-tunnel-credentials \
     --from-file=credentials.json=./credentials.json
   ```

4. Edit [`cloudflare-tunnel.yaml`](./cloudflare-tunnel.yaml):
   - set `{REPLACE_CLOUDFLARE_TUNNEL_ID}`
   - set `{REPLACE_PUBLIC_BASE_DOMAIN}`
5. Apply the tunnel manifest:

   ```bash
   kubectl apply -f vind-demo-cluster/cloudflare-tunnel.yaml
   ```

6. Verify the tunnel pod:

   ```bash
   kubectl -n cloudflare-tunnel get pods
   kubectl -n cloudflare-tunnel logs deploy/cloudflared
   ```

7. Point GitHub webhooks and GitHub App callback URLs at the public hostnames.

### Service Targets

The Argo CD route in [`cloudflare-tunnel.yaml`](./cloudflare-tunnel.yaml)
already targets the service created by the `vind` bootstrap:

- `http://argocd-server.argocd.svc.cluster.local:80`

The vCluster Platform route points at the normal
`loft` service installed by the Helm chart. Confirm it exists
after install with:

```bash
kubectl -n vcluster-platform get svc loft
```

### Practical Advice

- Use the local-contained Forgejo path as the default `vind` pattern.
- Use Cloudflare Tunnel only when the repo clone stays GitHub-backed and needs
  webhook-driven refresh or public preview links.
- Keep Tailscale as an optional private-access mode, not the default hostname
  or public-access pattern for this repo.

## Same-Org vs Different-Org

There are two supported conceptual modes for a repurposed clone of this repo.

### Same-Org Mode

The cloned repo, the application images, and the GitHub automation credentials
all live in the same GitHub org.

This is the simplest mode because:

- one repo credential can often cover all Git reads
- one GHCR credential can cover image pulls
- one GitHub automation credential can cover webhooks and PR flows

### Different-Org Mode

The cloned repo template lives in one org, while images or GitHub automation
may still belong to another org.

This mode requires treating these as separate concerns:

- `REPO_ORG`: where the cloned repo lives
- `IMAGE_ORG`: where GHCR images are pulled from or pushed to
- `AUTOMATION_GITHUB_ORG`: where GitHub webhook or PR automation credentials
  are scoped

The secret contract for both modes is documented in
[`docs/secret-contract.md`](../docs/secret-contract.md).

## Recommended Initial Scope

For the first working `vind` demo environment, enable only:

- vCluster Platform
- Argo CD
- ESO
- `vcluster-gitops/`
- one or two low-friction use cases

Hold these back until the secret flow is stable:

- Crossplane GitHub automation
- PR preview environments
- database connector
- snapshot publishing

## Next Implementation Steps

This folder is only the first layer. The follow-on work is:

1. define and maintain the repo secret contract
2. replace Demo Generator-projected secrets with ESO-managed secrets
3. add a dedicated Argo CD bootstrap application for the `vind` path
4. add per-use-case overlays or labels so only suitable demos are enabled in a
   self-contained environment

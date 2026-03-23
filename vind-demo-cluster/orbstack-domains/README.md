# OrbStack Domains for vind

This folder shows one practical way to give a `vind` cluster friendly local
hostnames like:

- <https://vcp.local>
- <https://argocd.vcp.local>
- <http://forgejo.vcp.local>

instead of relying on:

- the raw `vind` control-plane domain, for example `https://vcluster.cp.vcp.orb.local`
- raw ingress controller hostnames
- local IPs and ports

## Why This Exists

`vind` and OrbStack solve different parts of the local access problem:

- `vind` exposes wildcard app hosts through Kubernetes `Ingress` resources
- `vcp.local`, `argocd.vcp.local`, and `forgejo.vcp.local` each keep their own
  dedicated `LoadBalancer` upstream
- `ingress-nginx` stays as the wildcard app entrypoint
- those `LoadBalancer` services are backed by HAProxy containers on the
  per-cluster Docker network, for example `vcluster.vcp`
- OrbStack can assign nice local HTTPS domains to Docker containers
- OrbStack does not directly assign those friendly domains to Kubernetes
  services inside `vind`

So this folder uses a small Caddy container as a bridge:

- OrbStack gives the Caddy container friendly HTTPS hostnames
- Caddy reverse proxies those hostnames to the mixed `vind` upstreams
- the same Caddy container also advertises Docker-network aliases for
  `vcp.local`, `argocd.vcp.local`, and `forgejo.vcp.local`, so machine clients
  running on the `vind` network can reach the same hostnames without leaving
  the local Docker network

That is the main pattern.

## Files

- [compose.yaml](./compose.yaml): runs the Caddy adapter on the `vind` Docker network
- [Caddyfile](./Caddyfile): maps friendly hostnames to the shared ingress upstream

## How It Works

For a `vind` cluster named `vcp`, the Docker network is usually:

- `vcluster.vcp`

Typical upstreams look like:

- `vcluster.lb.vcp.loft.vcluster-platform:443`
- `vcluster.lb.vcp.argocd-server.argocd:80`
- `vcluster.lb.vcp.forgejo-http.forgejo:3000`
- `vcluster.lb.vcp.ingress-nginx-controller.ingress-nginx:80`

The Caddy container joins `vcluster.vcp`, so it can resolve and reach those
HAProxy-backed ingress endpoints directly.

OrbStack then gives the Caddy container these public-on-your-laptop local
domains:

- `vcp.local`
- `argocd.vcp.local`
- `forgejo.vcp.local`

Docker clients that also join `vcluster.vcp` see those same three hostnames as
network aliases for the Caddy container itself. That split keeps browser access
and in-cluster machine access on the same hostnames without leaking Kubernetes
service DNS names into image tags or callback URLs.

## Quick Tutorial

1. Create or upgrade your `vind` cluster.

```bash
vcluster create vcp --driver docker --upgrade --add=false --values vind-demo-cluster/vcluster.yaml
```

2. Generate the OrbStack adapter env file.

Preferred path:

```bash
bash vind-demo-cluster/start-orbstack-domains.sh --cluster-name vcp
```

That writes:

- `vind-demo-cluster/orbstack-domains/.env`

3. Start the adapter.

```bash
docker compose \
  --project-directory vind-demo-cluster/orbstack-domains \
  --project-name vind-local-domains-vcp \
  --env-file vind-demo-cluster/orbstack-domains/.env \
  -f vind-demo-cluster/orbstack-domains/compose.yaml \
  up -d
```

4. Open the local URLs.

- <https://vcp.local>
- <https://argocd.vcp.local>
- <http://forgejo.vcp.local>

## Manual Overrides

If you want to run multiple `vind` environments on the same laptop, override the
hostnames and cluster network in the env file.

Example:

```env
VIND_DOCKER_NETWORK=vcluster.team-a
VCP_HOST=team-a.vcp.local
ARGOCD_HOST=argocd.team-a.vcp.local
FORGEJO_HOST=forgejo.team-a.vcp.local
INGRESS_WILDCARD_HOST=*.team-a.vcp.local
ARGOCD_UPSTREAM=vcluster.lb.team-a.argocd-server.argocd:80
VCP_UPSTREAM=vcluster.lb.team-a.loft.vcluster-platform:443
FORGEJO_UPSTREAM=vcluster.lb.team-a.forgejo-http.forgejo:3000
INGRESS_UPSTREAM=vcluster.lb.team-a.ingress-nginx-controller.ingress-nginx:80
```

Then run Compose against that env file.

## Why Not Just Use the Raw OrbStack URLs

You can, but they are not a good operator default.

The raw URLs are:

- less memorable
- harder to document
- tied more directly to the internal `vind` wiring

The Caddy + OrbStack domain pattern gives you a stable local UX that behaves
more like a real demo environment.

## Docker Desktop

Something similar is possible with Docker Desktop, but not in the same clean,
native way.

Docker Desktop can expose Kubernetes services on `localhost`, and its docs note
that local `LoadBalancer` and ingress access commonly lands on `localhost`.
That is enough to build a local reverse-proxy pattern with Caddy or Traefik.

What Docker Desktop does not give you in the same way is OrbStack-style custom
container domains like `vcp.local` out of the box. So with Docker Desktop, the
usual shape would be:

- `localhost` or local ports for the Kubernetes services
- plus your own reverse proxy
- plus your own local DNS or hosts-file mapping if you want nice hostnames

So the general reverse-proxy idea is portable, but the smooth custom-domain
experience here is specifically an OrbStack advantage.

# Tenant Observability

This use case demonstrates tenant-scoped observability inside each vCluster using:

- Grafana
- Loki
- Prometheus
- Promtail
- a small sample workload that emits logs and exposes Prometheus metrics

Grafana also comes with a small default dashboard so the demo is usable immediately after sync.

> [!IMPORTANT]
> This use case has been validated on the OrbStack-backed self-contained `vind`
> path with the standard Central HostPath Mapper + Promtail design.
>
> The Demo Generator path is still unvalidated for the log collection part of
> this use case, because its nested vCluster topology may affect how CHPM
> resolves the final host log paths.

The important part is the deployment model:

1. the `tenant-observability-vcluster` template creates a tenant vCluster
2. that template automatically imports the tenant vCluster into the host Argo CD
3. a host-side Argo CD `ApplicationSet` sees the imported cluster labels
4. that `ApplicationSet` installs the observability stack into the tenant vCluster

So this follows the same pattern as `argocd-in-vcluster`, instead of embedding the whole observability stack directly in the `VirtualClusterTemplate`.

## What This Demonstrates

- each tenant vCluster gets its own local Grafana, Loki, and Prometheus
- metrics and dashboards should work anywhere the stack can run
- the supported path uses Promtail plus Central HostPath Mapper for tenant log collection
- the host Argo CD instance can manage add-ons inside imported tenant vCluster instances
- multiple tenant vCluster instances on the same host cluster stay isolated because each vCluster has its own stack and local datasources

Promtail is the collector used for the supported path.

## Recommended Validation Target

This use case is validated on `vind` and should also be validated on a direct self-managed host cluster.

That is still the cleanest CHPM path:

- host cluster
- vCluster Platform management cluster
- tenant vCluster instances

The Demo Generator path is still unvalidated for this use case because it adds extra nesting:

- parent host cluster
- Generator vCluster
- child vCluster Platform management vCluster
- tenant vCluster instances

Even if the final tenant pods land on the parent host nodes, that extra virtualization and sync depth may change how CHPM maps virtual pod identity back to the physical host log path.

## Host Prerequisites

The host cluster must have Central HostPath Mapper installed.

Relevant docs:

- [Central HostPath Mapper](https://www.vcluster.com/docs/platform/maintenance/monitoring/central-hostpath-mapper)

Why it is needed:

- log collectors usually read pod logs from host paths like `/var/log/pods`
- vCluster rewrites synced pod names on the host side
- Central HostPath Mapper provides vCluster-scoped symlinks so collectors inside the vCluster can still reach the correct host log files

The tenant template includes the required vCluster config already:

```yaml
controlPlane:
  backingStore:
    etcd:
      embedded:
        enabled: true
  coredns:
    embedded: true
  hostPathMapper:
    enabled: true
    central: true
```

When this use case is enabled through this repo, host Argo CD also installs the Central HostPath Mapper Helm chart on the host cluster:

- [apps/tenant-observability-central-hostpath-mapper.yaml](./apps/tenant-observability-central-hostpath-mapper.yaml)

That `Application` installs:

- chart: `central-hostpath-mapper`
- repo: `https://charts.loft.sh/`
- version: `0.3.0-rc.1`

So for the normal Generator and self-managed host-cluster flows, you do not need a separate manual install step for Central HostPath Mapper.

For the `vind` path, the management cluster also needs an ingress controller if you want tenant UIs reachable from your laptop. The `vind` bootstrap installs `ingress-nginx`, and the OrbStack/Caddy adapter can route `*.vcp.local` to it.

## How It Is Bootstrapped

The management-cluster Argo CD flow is:

- [apps/tenant-observability-manifests.yaml](./apps/tenant-observability-manifests.yaml) applies the template and example instance manifests
- [apps/tenant-observability-applicationsets.yaml](./apps/tenant-observability-applicationsets.yaml) applies the imported-cluster `ApplicationSet`
- [applicationsets/tenant-observability-cluster-gen.yaml](./applicationsets/tenant-observability-cluster-gen.yaml) watches imported clusters labeled `addons.vcluster.demo/tenant-observability=true` and installs the stack into each one

On the standard Generator / self-managed host-cluster path, Argo CD also installs:

- [apps/tenant-observability-central-hostpath-mapper.yaml](./apps/tenant-observability-central-hostpath-mapper.yaml)

The tenant stack itself lives here:

- [stack/](./stack/)

That stack contains:

- Grafana
- Loki
- Prometheus
- kube-state-metrics
- Promtail
- the sample workload

## Enable It

Enable the use case on the management cluster:

```bash
kubectl -n argocd label secret cluster-local tenantObservability=true --overwrite
```

Or with the `vind` helper:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --use-cases eso,tenant-observability
```

Then create tenant vCluster instances from this template:

- [manifests/tenant-observability-vcluster-template.yaml](./manifests/tenant-observability-vcluster-template.yaml)

An example instance in the default project is included:

- [manifests/tenant-observability-instance.yaml](./manifests/tenant-observability-instance.yaml)

## Validate Tenant Isolation

Create two tenant vCluster instances:

- `team-a`
- `team-b`

Validation flow:

1. open Grafana for `team-a`
2. confirm the default `Tenant Observability Overview` dashboard loads
3. confirm Grafana datasources are only local Prometheus and local Loki
4. query Loki for `tenant-observability demo message`
5. query Prometheus for `tenant_observability_demo_messages_total`
6. repeat the same checks in `team-b`
7. confirm `team-a` data does not appear in `team-b`, and vice versa

The template adds `Grafana` and `Prometheus` custom links to the vCluster instance so those UIs are easy to open from the Platform UI.

For the `vind` local-domain path, those links use the wildcard hostname shape:

- `grafana-<vcluster>.vcp.local`
- `prometheus-<vcluster>.vcp.local`

The default dashboard includes:

- total demo messages
- sample uptime
- demo identity labels from Prometheus
- recent demo logs from Loki

A second dashboard is also provisioned:

- `Kubernetes Workload Overview`

That dashboard uses `kube-state-metrics` scraped by Prometheus for:

- running and pending pods
- container restarts
- available deployment replicas
- pod phase breakdown

`metrics-server` is not required for these Grafana dashboards. Prometheus needs exported metrics to scrape, and `kube-state-metrics` is the lightweight source for the standard Kubernetes object metrics used here.

## Confirm HostPath Mapper Is Working

Inside a tenant vCluster:

```bash
kubectl -n tenant-observability get pods -l app.kubernetes.io/name=promtail
kubectl -n tenant-observability exec <promtail-pod> -- ls /var/log/pods | head
```

Then in Grafana Explore, query Loki for:

- `tenant-observability demo message`

If Central HostPath Mapper is missing on the standard path, Promtail will usually start but the tenant workload logs will not show up in Loki.

## Scaling Notes

This is intentionally lightweight:

- Loki is single-binary with ephemeral local storage
- Prometheus is a single replica
- Grafana is a single replica
- Promtail is a DaemonSet

Things to watch first:

- one Promtail pod runs per node per tenant vCluster on the standard path
- many tenant vCluster instances on the same host cluster will increase Promtail fanout
- Loki, Prometheus, and Grafana state are ephemeral in this PoV

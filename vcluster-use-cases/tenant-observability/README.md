# Tenant Observability

This use case demonstrates a tenant-scoped observability stack inside each
vCluster instance.

What it installs inside the tenant vCluster:

- Grafana
- Loki
- Prometheus
- Promtail
- a small sample workload that emits logs every few seconds and exposes
  Prometheus metrics

Promtail is the default collector for this PoV. An optional Grafana Alloy
scaffold is included under [scaffolds/](./scaffolds), but it is not wired into
the template by default.

## What This Demonstrates

- each vCluster gets its own local observability stack
- Grafana talks only to the local Prometheus and Loki services inside that
  tenant vCluster
- Promtail reads pod logs through Central HostPath Mapper instead of trying to
  resolve host log paths directly
- multiple tenant vClusters can run on the same host cluster without sharing
  Grafana, Loki, or Prometheus state

## Host Prerequisites

The host cluster must have Central HostPath Mapper installed.

Why it is needed:

- log collectors usually read pod logs from host paths like `/var/log/pods`
- vCluster rewrites synced pod names on the host side
- Central HostPath Mapper exposes vCluster-scoped symlinks so collectors inside
  the vCluster can still reach the correct host log files

Required vCluster config for this use case:

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

This template intentionally uses:

- embedded etcd
- embedded CoreDNS
- Central HostPath Mapper

so the demo looks like a more fully featured tenant vCluster instead of the
lightest possible control plane.

The host-path-specific part of the required config is:

```yaml
controlPlane:
  hostPathMapper:
    enabled: true
    central: true
```

The demo template in
[manifests/tenant-observability-vcluster-template.yaml](./manifests/tenant-observability-vcluster-template.yaml)
includes that config already.

For the `vind` path, the management cluster should also run an ingress
controller. The `vind` bootstrap installs `ingress-nginx`, and the
OrbStack/Caddy adapter can route `*.vcp.local` to it so tenant app UIs are
reachable locally.

Relevant docs:

- [Central HostPath Mapper](https://www.vcluster.com/docs/platform/maintenance/monitoring/central-hostpath-mapper)
- [ingress-nginx install guide](https://kubernetes.github.io/ingress-nginx/deploy/)

## Deploy It

The repo follows the existing Argo CD pattern:

1. enable the `tenant-observability` use case on the management cluster
2. let Argo CD create the `tenant-observability-vcluster` template
3. create tenant vClusters from that template

Enable it through `cluster-local`:

```bash
kubectl -n argocd label secret cluster-local tenantObservability=true --overwrite
```

Or with the `vind` helper:

```bash
LICENSE_TOKEN="$TOKEN" bash vind-demo-cluster/bootstrap-self-contained.sh \
  --use-cases eso,tenant-observability
```

The use case installs this Argo CD `Application`:

- [apps/tenant-observability-manifests.yaml](./apps/tenant-observability-manifests.yaml)

That `Application` applies:

- [manifests/tenant-observability-vcluster-template.yaml](./manifests/tenant-observability-vcluster-template.yaml)
- [manifests/tenant-observability-instance.yaml](./manifests/tenant-observability-instance.yaml)

## Create Two Tenant vClusters

Create two vClusters from the `tenant-observability-vcluster` template:

- `team-a`
- `team-b`

This can be done from the vCluster Platform UI or with the
`VirtualClusterInstance` API, depending on how you are running the demo.

An example `VirtualClusterInstance` is included here:

- [manifests/tenant-observability-instance.yaml](./manifests/tenant-observability-instance.yaml)

The template adds a `Grafana` custom link to each tenant instance so you can
open the local Grafana for that vCluster directly from the Platform UI.

## Validate Tenant Isolation

Use this validation flow:

1. open Grafana for `team-a`
2. confirm the configured datasources are only:
   - local Prometheus
   - local Loki
3. query logs in Loki for:
   - `tenant-observability demo message`
4. confirm the log labels and content reference `team-a`
5. query the `tenant_observability_demo_messages_total` metric in Prometheus
6. repeat the same checks for `team-b`
7. confirm that `team-a` data does not appear in `team-b`, and vice versa

Why the isolation works in this PoV:

- every vCluster runs its own Grafana, Loki, and Prometheus
- Grafana uses only local datasources
- Promtail runs inside the tenant vCluster and reads that vCluster's mapped log
  paths through Central HostPath Mapper

The sample workload emits:

- log lines containing `tenant-observability demo message`
- the metric `tenant_observability_demo_messages_total`

## Confirm HostPath Mapper Is Actually in Use

Inside a tenant vCluster, validate the collector path directly:

```bash
kubectl -n tenant-observability get pods -l app.kubernetes.io/name=promtail
kubectl -n tenant-observability exec <promtail-pod> -- ls /var/log/pods | head
```

Then confirm that Loki receives the sample app logs:

1. open Grafana Explore
2. switch to the local Loki datasource
3. query for:
   - `tenant-observability demo message`
4. confirm the returned log lines include the tenant vCluster name

If Central HostPath Mapper is missing or the vCluster was not created from the
provided template, Promtail will usually come up but you will not see the
expected tenant pod logs in Loki.

## Scaling Notes

This demo is intentionally lightweight:

- Loki is single-binary with local filesystem storage
- Prometheus is a single replica
- Grafana is a single replica
- Promtail runs as a DaemonSet

That is enough for a tenant observability demo, but it is not a production HA
design.

Scaling considerations:

- one Promtail pod runs per node per tenant vCluster
- if you create many tenant vClusters on the same host cluster, Promtail fanout
  is the main thing to watch first
- Loki and Prometheus storage are ephemeral in this PoV
- Grafana state is also ephemeral

## Assumptions

- the tenant vClusters are created from the provided template, or from another
  template that includes the same Central HostPath Mapper config
- the management cluster needs an ingress controller for these Ingress objects
  to resolve; on the `vind` path that is installed from `vind-demo-cluster/vcluster.yaml`
- the tenant ingress hostnames still need a reachable endpoint and DNS or local
  host mapping for the ingress controller service
- this use case keeps everything as raw Kubernetes manifests inside the
  `VirtualClusterTemplate` to avoid requiring Argo CD or Helm inside each
  tenant vCluster just for the demo

## Collector Alternative

Optional Grafana Alloy scaffold:

- [scaffolds/grafana-alloy.config.alloy](./scaffolds/grafana-alloy.config.alloy)

It is provided only as a future alternative collector starting point. Promtail
remains the default collector in the current demo.

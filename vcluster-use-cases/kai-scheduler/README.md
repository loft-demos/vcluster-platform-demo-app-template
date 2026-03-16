# KAI Scheduler

This folder contains KAI scheduler examples for running vCluster workloads with
a scheduler that is installed on the host cluster.

Current example:

- [`shared-from-host/`](./shared-from-host/)
  shows the pattern for using a host-installed KAI scheduler by setting
  `.spec.schedulerName = kai-scheduler` on workload pods

The main caveat called out in the example is ownership of synced workload pods.
If the KAI pod grouper needs to traverse owner references cleanly, it may be
necessary to disable the default vCluster owner reference behavior for synced
pods.

Start here:

- [shared-from-host/README.md](./shared-from-host/README.md)

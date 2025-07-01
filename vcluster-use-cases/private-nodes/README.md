# vCluster Private Nodes

vCluster Private Nodes is a feature that allows attaching external, self-managed compute resources—typically virtual machines or bare metal servers—as dedicated nodes for a vCluster control plane. These private nodes run outside the host cluster that vCluster itself is deployed in, enabling isolation of workloads from the host’s compute environment. This approach allows the use of a different CNI and different CSIs, and is ideal for scenarios requiring stricter security boundaries, custom kernel modules, or specialized hardware (like GPUs), while still benefiting from the ease of using vCluster.


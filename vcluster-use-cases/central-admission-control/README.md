# Central Admission Control for vCluster

Centralized Admission Control is an advanced feature for cluster admins that have custom rules that they need to apply to the virtual cluster. Cluster admins can enforce Kubernetes admission webhooks that reference the host cluster or external policy services from within the virtual cluster. Examples of validating and mutating webhook based policy engines include OPA, Kyverno, and jsPolicy.

This example uses Kyverno and deploys a Kyverno `ClusterPolicy` that does not allow `Pods` or `Pod` controllers to be created in the `default` namespace.
locals {
  project = module.validation.project
  region  = module.validation.region
  zone    = module.validation.zone

  demo_env_name      = nonsensitive(var.vcluster.nodeType.spec.properties["demo-env-name"])
  vcluster_name      = var.vcluster.instance.metadata.name
  vcluster_namespace = var.vcluster.instance.metadata.namespace

  network_name = var.vcluster.nodeEnvironment.outputs["network_name"]
  subnet_name  = var.vcluster.nodeEnvironment.outputs["subnet_name"]

  instance_type = var.vcluster.nodeType.spec.properties["instance-type"]

  # New: capture spot property from NodeType
  use_spot = try(
    lower(var.vcluster.nodeType.spec.properties["spot"]) == "true",
    false
  )
}
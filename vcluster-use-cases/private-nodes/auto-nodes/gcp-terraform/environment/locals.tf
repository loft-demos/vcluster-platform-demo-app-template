locals {
  project = module.validation.project
  region  = module.validation.region

  demo_env_name      = nonsensitive(var.vcluster.nodeType.spec.properties["demo-env-name"])
  vcluster_name      = nonsensitive(var.vcluster.instance.metadata.name)
  vcluster_namespace = nonsensitive(var.vcluster.instance.metadata.namespace)

  vpc_name            = "${var.vcluster.name}-${local.demo_env_name}-${random_id.vpc_suffix.hex}-vpc"
  public_subnet_cidr  = "10.10.2.0/24"
  public_subnet_name  = "${local.vcluster_name}-${local.demo_env_name}-public"
  private_subnet_cidr = "10.10.1.0/24"
  private_subnet_name = "${local.vcluster_name}-${local.demo_env_name}-private"

  nat_name        = "${local.vcluster_name}-${local.demo_env_name}-nat"
  nat_router_name = "${local.vcluster_name}-${local.demo_env_name}-router"
}
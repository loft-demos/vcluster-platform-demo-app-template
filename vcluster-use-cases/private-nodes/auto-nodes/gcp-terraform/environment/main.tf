provider "google" {
  project = local.project
  region  = local.region
}

module "validation" {
  source = "./validation"

  project = nonsensitive(var.vcluster.requirements["project"])
  region  = nonsensitive(var.vcluster.requirements["region"])
}

resource "random_id" "vpc_suffix" {
  byte_length = 4
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 11.1"

  project_id   = local.project
  network_name = local.vpc_name

  subnets = [
    {
      subnet_name           = local.public_subnet_name
      subnet_ip             = local.public_subnet_cidr
      subnet_region         = local.region
      subnet_private_access = "true"
    },
    {
      subnet_name           = local.private_subnet_name
      subnet_ip             = local.private_subnet_cidr
      subnet_region         = local.region
      subnet_private_access = "true"
    }
  ]
}


module "cloud_nat" {
  source  = "terraform-google-modules/cloud-nat/google"
  version = "~> 5.0"

  project_id                         = local.project
  region                             = local.region
  name                               = local.nat_name
  router                             = local.nat_router_name
  create_router                      = true
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  network                            = module.vpc.network_self_link
}
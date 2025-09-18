locals {
  firewall_rules = {
    # Allow SSH access via IAP (Identity-Aware Proxy)
    "allow-iap-ssh" = {
      description   = "Allow SSH access via Identity-Aware Proxy"
      source_ranges = ["35.235.240.0/20"] # IAP source ranges
      target_tags   = ["allow-iap-ssh"]
      direction     = "INGRESS"
      allow = [{
        protocol = "tcp"
        ports    = ["22"]
      }]
      deny = []
    }
    # Allow HTTP/HTTPS traffic for public instances
    "allow-web-traffic" = {
      description   = "Allow HTTP and HTTPS traffic"
      source_ranges = ["0.0.0.0/0"]
      direction     = "INGRESS"
      allow = [{
        protocol = "tcp"
        ports    = ["80", "443"]
      }]
    }
    # Allow internal communication between subnets
    "allow-internal" = {
      description   = "Allow internal communication within VPC"
      source_ranges = [local.public_subnet_cidr, local.private_subnet_cidr]
      direction     = "INGRESS"
      allow = [
        {
          protocol = "tcp"
          ports    = ["0-65535"]
        },
        {
          protocol = "udp"
          ports    = ["0-65535"]
        },
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    # Allow health checks from Google Cloud Load Balancer
    "allow-health-check" = {
      description   = "Allow health checks from Google Cloud Load Balancer"
      priority      = 1000
      source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
      direction     = "INGRESS"
      allow = [{
        protocol = "tcp"
        ports    = ["80", "443", "8080"]
      }]
    }
  }
}

resource "google_compute_firewall" "rules" {
  for_each = local.firewall_rules

  project     = local.project
  name        = "${local.vpc_name}-${each.key}"
  network     = module.vpc.network_self_link
  description = each.value.description
  direction   = each.value.direction

  source_ranges = lookup(each.value, "source_ranges", null)
  target_tags   = lookup(each.value, "target_tags", null)

  dynamic "allow" {
    for_each = each.value.allow
    content {
      protocol = allow.value.protocol
      ports    = length(allow.value.ports) > 0 ? allow.value.ports : null
    }
  }

  depends_on = [module.vpc]
}
variable "project" {
  type        = string
  description = "The GCP project"
}

variable "region" {
  type        = string
  description = "The GCP region"
}

provider "google" {
  project = local.project
  region  = local.region
}

locals {
  region  = nonsensitive(split(",", var.region)[0])
  project = nonsensitive(split(",", var.project)[0])
}

data "google_project" "project" {
}

resource "null_resource" "validate_project" {
  lifecycle {
    precondition {
      condition     = length(trimspace(local.project)) > 0
      error_message = "Project cannot be empty. Please provide a valid Project"
    }

    precondition {
      condition     = local.project != "*" && !can(regex("[*?\\[\\]{}]", local.project))
      error_message = "Project cannot be a glob pattern or contain wildcards. Received: '${local.project}'"
    }
  }
}

data "google_compute_regions" "available" {
}

resource "null_resource" "validate_region" {
  lifecycle {
    precondition {
      condition     = length(trimspace(local.region)) > 0
      error_message = "Region cannot be empty. Please provide a valid GCP region."
    }

    precondition {
      condition     = local.region != "*" && !can(regex("[*?\\[\\]{}]", local.region))
      error_message = "Region cannot be a glob pattern or contain wildcards. Received: '${local.region}'"
    }

    precondition {
      condition     = contains([for r in data.google_compute_regions.available.names : r], local.region)
      error_message = "Region '${local.region}' does not exist. Please provide a valid GCP region."
    }
  }
}

output "region" {
  value = local.region
}

output "project" {
  value = local.project
}
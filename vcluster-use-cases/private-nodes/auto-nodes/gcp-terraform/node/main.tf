provider "google" {
  project = local.project
  region  = local.region
}

module "validation" {
  source = "./validation"

  project       = nonsensitive(var.vcluster.requirements["project"])
  region        = nonsensitive(var.vcluster.requirements["region"])
  zone          = try(nonsensitive(var.vcluster.requirements["zone"]), "")
  
}

resource "random_id" "vm_suffix" {
  byte_length = 4
}

module "private_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 13.0"

  region            = local.region
  zone              = local.zone == "" ? null : local.zone
  subnetwork        = local.subnet_name
  num_instances     = 1
  hostname          = "${var.vcluster.name}-${local.demo_env_name}-${random_id.vm_suffix.hex}"
  instance_template = google_compute_instance_template.spot_tpl.self_link

  # Will use NAT
  access_config = []

  labels = {
    vcluster  = local.vcluster_name
    namespace = local.vcluster_namespace
    demoEnv   = local.demo_env_name
  }
}

data "google_project" "project" {
  project_id = local.project
}

data "google_compute_image" "img" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

module "instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 13.0"

  region             = local.region
  project_id         = local.project
  network            = local.network_name
  subnetwork         = local.subnet_name
  subnetwork_project = local.project
  tags               = ["allow-iap-ssh"] # for IAP SSH access

  machine_type = local.instance_type

  source_image         = data.google_compute_image.img.self_link
  source_image_family  = data.google_compute_image.img.family
  source_image_project = data.google_compute_image.img.project

  disk_size_gb = 100
  disk_type    = "pd-standard"

  service_account = {
    # Use default compute service account
    email  = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = var.vcluster.userData
  }

  startup_script = "#!/bin/bash\n# Ensure cloud-init runs\ncloud-init status --wait || true"
}

resource "google_compute_instance_template" "spot_tpl" {
  project     = local.project
  name_prefix = "${var.vcluster.name}-${local.demo_env_name}-"
  region      = local.region

  machine_type = local.instance_type

  disk {
    source_image = data.google_compute_image.img.self_link
    auto_delete  = true
    boot         = true
    disk_type    = "pd-standard"
    disk_size_gb = 100
  }

  network_interface {
    subnetwork = local.subnet_name
  }

  service_account {
    email  = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = var.vcluster.userData
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    cloud-init status --wait || true
  EOT

  scheduling {
    provisioning_model  = local.use_spot ? "SPOT" : "STANDARD"
    preemptible         = local.use_spot
    automatic_restart   = local.use_spot ? false : true
    on_host_maintenance = local.use_spot ? "TERMINATE" : "MIGRATE"
  }
}
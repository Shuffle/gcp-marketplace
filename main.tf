terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }

  }
}

provider "google" {
  project = var.project_id
  region  = local.region
}

locals {
  deployment_name = var.goog_cm_deployment_name
  network_name    = "${local.deployment_name}-network"
  
  # Extract region from zone (e.g., us-central1-a -> us-central1)
  region = join("-", slice(split("-", var.zone), 0, 2))

  # Get all available zones in the region
  available_zones = data.google_compute_zones.available.names
  
  # For single node: use first zone (zone-a)
  # For multiple nodes: distribute across zones (a, b, c, etc.)
  zones = local.available_zones

  total_nodes   = var.node_count
  manager_nodes = var.node_count  # All nodes are managers
  worker_nodes  = 0                # No dedicated worker nodes

  opensearch_replicas       = min(local.total_nodes, 3)
  opensearch_index_replicas = local.opensearch_replicas - 1
  opensearch_initial_masters = join(",", [
    for i in range(1, local.opensearch_replicas + 1) : "shuffle-opensearch-${i}"
  ])
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = local.region
  status  = "UP"
}


resource "google_compute_network" "shuffle_network" {
  name                    = local.network_name
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "shuffle_subnet" {
  name          = "${local.deployment_name}-subnet"
  network       = google_compute_network.shuffle_network.id
  ip_cidr_range = var.subnet_cidr
  region        = local.region
  project       = var.project_id
}

resource "google_compute_firewall" "swarm_internal" {
  name    = "${local.deployment_name}-swarm-internal"
  network = google_compute_network.shuffle_network.name
  project = var.project_id

  # Docker Swarm cluster communication (internal only)
  allow {
    protocol = "tcp"
    ports    = ["2376", "2377", "7946"]
  }

  allow {
    protocol = "udp"
    ports    = ["7946", "4789"]
  }

  # NFS for shared storage (internal only)
  allow {
    protocol = "tcp"
    ports    = ["2049", "111", "51771", "48095", "48096", "32769"]
  }

  allow {
    protocol = "udp"
    ports    = ["111", "2049", "51771", "48095", "48096", "32769"]
  }

  # Internal services (OpenSearch, Backend, Workers)
  allow {
    protocol = "tcp"
    ports    = ["9200", "9300", "5001", "5002", "33333", "33334", "33335", "33336"]
  }

  # Memcached
  allow {
    protocol = "tcp"
    ports    = ["11211"]
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = ["${local.deployment_name}-node"]
}

resource "google_compute_firewall" "shuffle_external" {
  name    = "${local.deployment_name}-external"
  network = google_compute_network.shuffle_network.name
  project = var.project_id

  # ONLY expose port 3001 (Frontend HTTP) externally
  allow {
    protocol = "tcp"
    ports    = ["3001"]
  }

  allow {
    protocol = "udp"
    ports    = ["3001"]
  }

  source_ranges = split(",", var.external_access_cidrs)
  target_tags   = ["${local.deployment_name}-node"]
}

resource "google_compute_firewall" "ssh" {
  count   = var.enable_ssh ? 1 : 0
  name    = "${local.deployment_name}-ssh"
  network = google_compute_network.shuffle_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = split(",", var.ssh_source_ranges)
  target_tags   = ["${local.deployment_name}-node"]
}

resource "google_compute_instance" "swarm_manager" {
  count        = local.manager_nodes
  name         = "${local.deployment_name}-manager-${count.index + 1}"
  machine_type = var.machine_type
  zone         = local.zones[count.index % length(local.zones)]
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = var.source_image != "" ? var.source_image : "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.shuffle_subnet.id

    access_config {
      network_tier = "PREMIUM"
    }
  }

  metadata = {
    enable-oslogin = "FALSE"

    node-role       = "manager"
    node-index      = count.index
    is-primary      = count.index == 0 ? "true" : "false"
    deployment-name = local.deployment_name
    total-nodes     = local.total_nodes
    manager-nodes   = local.manager_nodes

    nfs-master-ip   = count.index == 0 ? "self" : "PRIMARY_MANAGER_IP"
    primary-manager = count.index == 0 ? "self" : "PRIMARY_MANAGER_IP"

    opensearch-replicas        = local.opensearch_replicas
    opensearch-index-replicas  = local.opensearch_index_replicas
    opensearch-initial-masters = local.opensearch_initial_masters

    startup-script = replace(file("${path.module}/scripts/startup-simple.sh"), "\r\n", "\n")
    swarm-yaml = replace(file("${path.module}/config/swarm.yaml"), "\r\n", "\n")
    deploy-sh = replace(file("${path.module}/config/deploy.sh"), "\r\n", "\n")
    setup-nfs-server-sh = replace(file("${path.module}/config/setup-nfs-server.sh"), "\r\n", "\n")
    env-file = replace(file("${path.module}/config/.env"), "\r\n", "\n")
    nginx-main-conf = replace(file("${path.module}/config/nginx-main.conf"), "\r\n", "\n")
    monitor-db-permissions-sh = replace(file("${path.module}/scripts/monitor-db-permissions.sh"), "\r\n", "\n")
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write"
    ]
  }

  tags = ["${local.deployment_name}-node", "${local.deployment_name}-manager"]

  labels = {
    deployment            = local.deployment_name
    node-role             = "manager"
    environment           = var.environment
    goog-partner-solution = "isol_plb32_001kf00000wicu3iai_qjbz3ffz4x7gg22x7o7abq4qgmbnyrq7"
  }

  depends_on = [
    google_compute_firewall.swarm_internal,
    google_compute_firewall.shuffle_external
  ]
}

# All nodes are now managers - no separate worker nodes needed

resource "google_compute_instance_group" "managers" {
  count = local.manager_nodes

  name    = "${local.deployment_name}-managers-${count.index + 20}"
  zone    = local.zones[count.index % length(local.zones)]
  project = var.project_id

  instances = [google_compute_instance.swarm_manager[count.index].self_link]

  named_port {
    name = "http"
    port = 3001
  }

  named_port {
    name = "https"
    port = 3443
  }
}


locals {
  primary_manager_ip = google_compute_instance.swarm_manager[0].network_interface[0].access_config[0].nat_ip
  frontend_url       = "http://${local.primary_manager_ip}:3001"
}


resource "time_sleep" "wait_for_shuffle_boot" {
  depends_on = [google_compute_instance.swarm_manager]

  # Give the VMs 60s to boot and start Shuffle
  create_duration = "60s"
}




data "http" "shuffle_checkusers" {
  depends_on = [
    time_sleep.wait_for_shuffle_boot,
  ]

  url = "${local.frontend_url}/api/v1/checkusers"
  retry {
    attempts     = 50      # MAX_ATTEMPTS=50
    min_delay_ms = 60000   # 60 seconds
    max_delay_ms = 60000
  }
}



resource "null_resource" "wait_for_shuffle_deployment" {
  depends_on = [
    data.http.shuffle_checkusers,
  ]

  lifecycle {
    postcondition {
      # Require HTTP 200; anything else is treated as failure
      condition = data.http.shuffle_checkusers.status_code == 200

      error_message = <<-EOT
        Timeout or failure while waiting for Shuffle to become accessible at: ${local.frontend_url}

        We attempted to call: ${local.frontend_url}/api/v1/checkusers
        up to 50 times (about 50 minutes) after VM boot.

        The VM may still be starting up or Shuffle may have failed to start.
        Check the VM startup logs for details, for example:

          gcloud compute ssh ${google_compute_instance.swarm_manager[0].name} --zone=${google_compute_instance.swarm_manager[0].zone}

        Then inspect the Shuffle service logs and retry the deployment.
      EOT
    }
  }
}


terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.18.1"
    }
  }
}

locals {
  # Determine if we're using a custom network or the default
  using_custom_network = var.network != ""
  network_name         = local.using_custom_network ? var.network : "default"

  # For naming resources
  cluster_name = "ltf-autopilot-cluster"

  # Create namespace+SA identifier for Workload Identity
  k8s_namespace = "${local.resource_prefix}-ns"
  k8s_sa_name   = "${local.resource_prefix}-sa"
}

# Create the service account if it doesn't exist
resource "google_service_account" "service_account" {
  account_id   = "${local.resource_prefix}-ltf-sa"
  display_name = "${local.resource_prefix}-ltf-sa"
  project      = var.project_id

  # This will make Terraform try to create the service account if it doesn't exist
  # but if it does, it will import it instead of erroring
  lifecycle {
    ignore_changes = [
      display_name,
    ]
  }
}

# Allow workload identity binding between K8s SA and GCP SA
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.service_account.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${local.k8s_namespace}/${local.k8s_sa_name}]"
  ]
}

# Grant AI Platform user role to service account - without this binding method
resource "google_project_iam_member" "direct_aiplatform_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_binding" "artifactregistry_reader_binding" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_project_iam_binding" "container_default_node_service_account_binding" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

# If using custom networking, ensure secondary ranges are set up
resource "google_compute_subnetwork" "gke_subnetwork" {
  count         = var.enable_psc_support && var.subnetwork == "" && local.using_custom_network ? 1 : 0
  name          = "gke-psc-subnet"
  ip_cidr_range = "10.2.0.0/16"
  region        = var.region
  network       = local.network_name
  project       = var.project_id

  secondary_ip_range {
    range_name    = "pod-range"
    ip_cidr_range = var.gke_pod_subnet_range
  }

  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = var.gke_service_subnet_range
  }

  private_ip_google_access = true
}

resource "google_container_cluster" "ltf_autopilot_cluster" {
  name                = "${local.resource_prefix}-ltf-autopilot-cluster"
  project             = var.project_id
  location            = var.region
  enable_autopilot    = true
  deletion_protection = false

  # Network configuration based on user input or defaults
  network = local.using_custom_network ? local.network_name : null
  subnetwork = var.subnetwork != "" ? var.subnetwork : (
    var.enable_psc_support && local.using_custom_network ?
    google_compute_subnetwork.gke_subnetwork[0].self_link : null
  )

  # Private cluster configuration for PSC support
  dynamic "private_cluster_config" {
    for_each = var.use_private_endpoint || var.enable_psc_support ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = var.use_private_endpoint
      master_ipv4_cidr_block  = var.master_ipv4_cidr_block
    }
  }

  # Add this new block to configure master authorized networks
  dynamic "master_authorized_networks_config" {
    for_each = var.use_private_endpoint ? [1] : []
    content {
      # This enables master authorized networks control
      # Without specifying any networks, access is blocked from everywhere
      # You need to add at least one CIDR range that should have access
      cidr_blocks {
        cidr_block   = "10.0.0.0/8" # This allows access from your VPC network
        display_name = "VPC Networks"
      }
    }
  }

  # IP allocation policy for GKE with PSC
  dynamic "ip_allocation_policy" {
    for_each = var.enable_psc_support ? [1] : []
    content {
      cluster_secondary_range_name  = var.subnetwork != "" ? null : "pod-range"
      services_secondary_range_name = var.subnetwork != "" ? null : "services-range"
    }
  }

  # Enable Workload Identity Federation
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.service_account.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }

  # Ignore changes to node_config for autopilot
  lifecycle {
    ignore_changes = [
      node_config,
    ]
  }
}

# Create a firewall rule to allow inbound traffic to Vector Search endpoints 
# (using IP-based approach instead of tags)
resource "google_compute_firewall" "allow_psc_ingress" {
  count   = var.enable_psc_support && local.using_custom_network ? 1 : 0
  name    = "${lower(replace(var.deployment_id, "/[^a-z0-9\\-]+/", ""))}-allow-psc-for-vector-search"
  network = local.network_name
  project = var.project_id

  description = "Allow communication between GKE and Vector Search via PSC"
  direction   = "INGRESS"

  # Allow from GKE to the Vector Search PSC
  allow {
    protocol = "tcp"
    ports    = ["443", "8080-8090", "10000"] # Ports used by Vector Search
  }

  # Source is all IP ranges used by GKE
  source_ranges = [
    var.master_ipv4_cidr_block,
    var.gke_pod_subnet_range,
    var.gke_service_subnet_range
  ]
}

# Create a firewall rule to allow communication between GKE and Vector Search
resource "google_compute_firewall" "allow_internal_communication" {
  count   = var.enable_psc_support && local.using_custom_network ? 1 : 0
  name    = "${lower(replace(var.deployment_id, "/[^a-z0-9\\-]+/", ""))}-allow-internal-network-communication"
  network = local.network_name
  project = var.project_id

  description = "Allow all internal communication within the network"
  direction   = "INGRESS"

  # Allow all protocols 
  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  # Source is the network itself
  source_ranges = ["10.0.0.0/8"]
}
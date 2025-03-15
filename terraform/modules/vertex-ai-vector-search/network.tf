terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.18.1"
    }
  }
}


# Create PSC address only when using Private Service Connect
resource "google_compute_address" "psc_address" {
  count   = var.enable_private_service_connect ? 1 : 0
  name    = "${lower(replace(var.deployment_id, "/[^a-z0-9\\-]+/", ""))}-ltf-psc-address"
  region  = var.region
  project = var.project_id
  # Use subnetwork directly from network_configuration
  subnetwork   = var.subnetwork
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  description  = "PSC address for Vector Search endpoint"
}

# Create forwarding rule only when using Private Service Connect
resource "google_compute_forwarding_rule" "psc_forwarding_rule" {
  count                 = var.enable_private_service_connect ? 1 : 0
  name                  = "${lower(replace(var.deployment_id, "/[^a-z0-9\\-]+/", ""))}-ltf-psc-forwarding-rule"
  region                = var.region
  project               = var.project_id
  network               = var.endpoint_network
  ip_address            = google_compute_address.psc_address[0].self_link
  target                = google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index.private_endpoints[0].service_attachment
  load_balancing_scheme = ""
  depends_on            = [google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index]
}

# Create peering range only when using VPC Peering
resource "google_compute_global_address" "vpc_peering_range" {
  count         = var.enable_vpc_peering ? 1 : 0
  name          = "${lower(replace(var.deployment_id, "/[^a-z0-9\\-]+/", ""))}-${var.peering_range_name}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.peering_prefix_length
  network       = var.endpoint_network
  project       = var.project_id
}

# Establish the VPC peering connection
resource "google_service_networking_connection" "vpc_peering_connection" {
  count                   = var.enable_vpc_peering ? 1 : 0
  network                 = var.endpoint_network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.vpc_peering_range[0].name]

  # Workaround to allow `terraform destroy`, see https://github.com/hashicorp/terraform-provider-google/issues/18729
  deletion_policy = "ABANDON"
}
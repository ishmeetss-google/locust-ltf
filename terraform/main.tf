terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.18.1"
    }
  }
}

provider "google" {
  region = var.region # Set the region at the provider level within the module
}

module "vector_search" {
  source = "./modules/vertex-ai-vector-search"

  # Pass variables to the module - these will be defined in root terraform.tfvars
  project_id                                 = var.project_id
  region                                     = var.region
  existing_bucket_name                       = var.existing_bucket_name
  vector_search_index_id                     = var.vector_search_index_id
  embedding_data_path                        = var.embedding_data_path
  index_display_name                         = var.index_display_name
  index_description                          = var.index_description
  index_labels                               = var.index_labels
  index_dimensions                           = var.index_dimensions
  index_approximate_neighbors_count          = var.index_approximate_neighbors_count
  index_distance_measure_type                = var.index_distance_measure_type
  index_shard_size                           = var.index_shard_size
  feature_norm_type                          = var.feature_norm_type
  index_algorithm_config_type                = var.index_algorithm_config_type
  index_tree_ah_leaf_node_embedding_count    = var.index_tree_ah_leaf_node_embedding_count
  index_tree_ah_leaf_nodes_to_search_percent = var.index_tree_ah_leaf_nodes_to_search_percent
  index_update_method                        = var.index_update_method
  index_create_timeout                       = var.index_create_timeout
  index_update_timeout                       = var.index_update_timeout
  index_delete_timeout                       = var.index_delete_timeout
  endpoint_display_name                      = var.endpoint_display_name
  endpoint_description                       = var.endpoint_description
  endpoint_labels                            = var.endpoint_labels
  endpoint_public_endpoint_enabled           = var.endpoint_public_endpoint_enabled
  endpoint_network                           = var.endpoint_network
  endpoint_enable_private_service_connect    = var.endpoint_enable_private_service_connect
  endpoint_create_timeout                    = var.endpoint_create_timeout
  endpoint_update_timeout                    = var.endpoint_update_timeout
  endpoint_delete_timeout                    = var.endpoint_delete_timeout
  deployed_index_id                          = var.deployed_index_id
  deployed_index_resource_type               = var.deployed_index_resource_type
  deployed_index_dedicated_machine_type      = var.deployed_index_dedicated_machine_type
  deployed_index_dedicated_min_replicas      = var.deployed_index_dedicated_min_replicas
  deployed_index_dedicated_max_replicas      = var.deployed_index_dedicated_max_replicas
  deployed_index_automatic_min_replicas      = var.deployed_index_automatic_min_replicas
  deployed_index_automatic_max_replicas      = var.deployed_index_automatic_max_replicas
  deployed_index_reserved_ip_ranges          = var.deployed_index_reserved_ip_ranges
  deployed_index_create_timeout              = var.deployed_index_create_timeout
  deployed_index_update_timeout              = var.deployed_index_update_timeout
  deployed_index_delete_timeout              = var.deployed_index_delete_timeout
}

# Add these resources to your main.tf file when Private Service Connect is enabled

# Only create these resources when Private Service Connect is enabled
resource "google_compute_address" "psc_address" {
  count       = var.endpoint_enable_private_service_connect ? 1 : 0
  name        = "ltf-psc-address"
  region      = var.region
  project     = var.project_id
  subnetwork  = var.subnetwork != "" ? var.subnetwork : null
  address_type = "INTERNAL"
  purpose     = "GCE_ENDPOINT"
  description = "PSC address for Vector Search endpoint"
}

resource "google_compute_forwarding_rule" "psc_forwarding_rule" {
  count                 = var.endpoint_enable_private_service_connect ? 1 : 0
  name                  = "ltf-psc-forwarding-rule"
  region                = var.region
  project               = var.project_id
  network               = var.endpoint_enable_private_service_connect ? (
                            var.endpoint_network != "" ? var.endpoint_network : 
                            "projects/${var.project_id}/global/networks/${var.psc_network_name}"
                          ) : null
  ip_address            = google_compute_address.psc_address[0].self_link
  target                = module.vector_search.service_attachment
  load_balancing_scheme = ""
  depends_on            = [module.vector_search]
  deployment_id                                   = var.deployment_id
}

module "gke_autopilot" {
  source = "./modules/gke-autopilot"

  project_id     = var.project_id
  region         = var.region
  project_number = var.project_number
  deployment_id  = var.deployment_id
  image          = var.image
  locust_test_type = var.locust_test_type

  # Pass network configuration for PSC support if enabled
  network = var.endpoint_enable_private_service_connect ? (
    var.endpoint_network != "" ? var.endpoint_network :
    "projects/${var.project_id}/global/networks/${var.psc_network_name}"
  ) : ""

  subnetwork         = var.subnetwork
  enable_psc_support = var.endpoint_enable_private_service_connect

  # Optional: Configure private endpoint settings
  use_private_endpoint   = var.use_private_endpoint
  master_ipv4_cidr_block = var.master_ipv4_cidr_block

  # IP ranges for GKE
  gke_pod_subnet_range     = var.gke_pod_subnet_range
  gke_service_subnet_range = var.gke_service_subnet_range
}

# Add this to your main.tf file after the modules

resource "google_compute_instance" "nginx_proxy" {
  name         = "${lower(replace(var.deployment_id, "/[^a-z0-9\\-]+/", ""))}-ltf-nginx-proxy"
  machine_type = "e2-micro"  # Choose an appropriate machine type
  zone         = "${var.region}-a"  # Adjust as needed
  project      = var.project_id  # Add this line to specify the project


  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  network_interface {
    # Use the same network as the endpoint when PSC is enabled, otherwise use default
    network = var.endpoint_enable_private_service_connect ? (
      var.endpoint_network != "" ? (
        # Extract network name from the full network path if provided
        replace(var.endpoint_network, "/^projects\\/[^\\/]+\\/global\\/networks\\//", "")
      ) : var.psc_network_name
    ) : "default"

    # If using PSC with a specific subnetwork, use that subnetwork
    subnetwork = var.endpoint_enable_private_service_connect && var.subnetwork != "" ? var.subnetwork : null

    # Only add public IP if not using private endpoints
    dynamic "access_config" {
      for_each = var.endpoint_enable_private_service_connect ? [] : [1]
      content {
        // Ephemeral public IP
      }
    }
  }
  metadata = {
    gce-container-declaration = <<EOT
spec:
  containers:
    - image: 'gcr.io/cloud-marketplace/google/nginx1:latest'
      name: nginx
      volumeMounts:
        - name: 'nginx-config'
          mountPath: '/etc/nginx/conf.d/default.conf'
          readOnly: true
  volumes:
    - name: 'nginx-config'
      hostPath:
        path: '/tmp/server.conf'
EOT

    startup-script = <<EOT
#!/bin/bash
cat <<EOFNGINX > /tmp/server.conf
server {
    listen 8089;
    location / {
        proxy_pass http://${module.gke_autopilot.locust_master_web_ip}:8089;
    }
}
EOFNGINX
EOT
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  # Allow stopping for update
  allow_stopping_for_update = true

  depends_on = [module.gke_autopilot]
}


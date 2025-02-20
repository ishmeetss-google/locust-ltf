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
  project_id                                      = var.project_id
  region                                          = var.region
  existing_bucket_name                            = var.existing_bucket_name
  vector_search_index_id                          = var.vector_search_index_id
  embedding_data_path                             = var.embedding_data_path
  index_display_name                              = var.index_display_name
  index_description                               = var.index_description
  index_labels                                    = var.index_labels
  index_dimensions                                = var.index_dimensions
  index_approximate_neighbors_count               = var.index_approximate_neighbors_count
  index_distance_measure_type                     = var.index_distance_measure_type
  feature_norm_type                               = var.feature_norm_type
  index_algorithm_config_type                     = var.index_algorithm_config_type
  index_tree_ah_leaf_node_embedding_count         = var.index_tree_ah_leaf_node_embedding_count
  index_tree_ah_leaf_nodes_to_search_percent      = var.index_tree_ah_leaf_nodes_to_search_percent
  index_update_method                             = var.index_update_method
  index_create_timeout                            = var.index_create_timeout
  index_update_timeout                            = var.index_update_timeout
  index_delete_timeout                            = var.index_delete_timeout
  endpoint_display_name                           = var.endpoint_display_name
  endpoint_description                            = var.endpoint_description
  endpoint_labels                                 = var.endpoint_labels
  endpoint_public_endpoint_enabled                = var.endpoint_public_endpoint_enabled
  endpoint_network                                = var.endpoint_network
  endpoint_enable_private_service_connect         = var.endpoint_enable_private_service_connect
  endpoint_create_timeout                         = var.endpoint_create_timeout
  endpoint_update_timeout                         = var.endpoint_update_timeout
  endpoint_delete_timeout                         = var.endpoint_delete_timeout
  deployed_index_id                               = var.deployed_index_id
  deployed_index_resource_type                    = var.deployed_index_resource_type
  deployed_index_dedicated_machine_type           = var.deployed_index_dedicated_machine_type
  deployed_index_dedicated_min_replicas           = var.deployed_index_dedicated_min_replicas
  deployed_index_dedicated_max_replicas           = var.deployed_index_dedicated_max_replicas
  deployed_index_dedicated_cpu_utilization_target = var.deployed_index_dedicated_cpu_utilization_target
  deployed_index_automatic_min_replicas           = var.deployed_index_automatic_min_replicas
  deployed_index_automatic_max_replicas           = var.deployed_index_automatic_max_replicas
  deployed_index_reserved_ip_ranges               = var.deployed_index_reserved_ip_ranges
  deployed_index_create_timeout                   = var.deployed_index_create_timeout
  deployed_index_update_timeout                   = var.deployed_index_update_timeout
  deployed_index_delete_timeout                   = var.deployed_index_delete_timeout
}

module "gke_autopilot" {
  source = "./modules/gke-autopilot"

  project_id     = var.project_id
  region         = var.region
  project_number = var.project_number
  image          = var.image
}

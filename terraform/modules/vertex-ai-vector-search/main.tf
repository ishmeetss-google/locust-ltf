# modules/vertex-ai-vector-search/main.tf

 terraform {
    required_providers {
      google = {
        source  = "hashicorp/google"
        version = "~> 5.0"  # Update to a version that supports the resource
      }
    }
  }

# -----------------------------------------------------------------------------
# Vertex AI Index Resource
# -----------------------------------------------------------------------------
resource "google_vertex_ai_index" "vector_index" {
  provider     = google
  region       = var.region
  display_name = var.index_display_name
  description  = var.index_description
  labels       = var.index_labels

  metadata {
    contents_delta_uri = "gs://${var.existing_bucket_name}/${var.embedding_data_path}"
    config {
      dimensions                  = var.index_dimensions
      approximate_neighbors_count = var.index_approximate_neighbors_count
      distance_measure_type       = var.index_distance_measure_type
      feature_norm_type = var.feature_norm_type

      dynamic "algorithm_config" {
        for_each = var.index_algorithm_config_type == "tree_ah_config" ? [1] : []
        content {
          tree_ah_config {
            leaf_node_embedding_count    = var.index_tree_ah_leaf_node_embedding_count
            leaf_nodes_to_search_percent = var.index_tree_ah_leaf_nodes_to_search_percent
          }
        }
      }

      dynamic "algorithm_config" {
        for_each = var.index_algorithm_config_type == "brute_force_config" ? [1] : []
        content {
          brute_force_config {}
        }
      }
    }
  }
  index_update_method = var.index_update_method

  timeouts {
    create = var.index_create_timeout
    update = var.index_update_timeout
    delete = var.index_delete_timeout
  }
}

# -----------------------------------------------------------------------------
# Vertex AI Index Endpoint Resource
# -----------------------------------------------------------------------------
resource "google_vertex_ai_index_endpoint" "vector_index_endpoint" {
  provider              = google
  region                  = var.region
  display_name          = var.endpoint_display_name
  description           = var.endpoint_description
  labels                = var.endpoint_labels
  public_endpoint_enabled = var.endpoint_public_endpoint_enabled

  network = var.endpoint_network

  dynamic "private_service_connect_config" {
    for_each = var.endpoint_enable_private_service_connect ? [1] : []
    content {
      enable_private_service_connect = true
    }
  }

  timeouts {
    create = var.endpoint_create_timeout
    update = var.endpoint_update_timeout
    delete = var.endpoint_delete_timeout
  }
}

# -----------------------------------------------------------------------------
# Vertex AI Deployed Index Resource (Deploy Index to Endpoint)
# -----------------------------------------------------------------------------
resource "google_vertex_ai_index_endpoint_deployed_index" "deployed_vector_index" {
  provider          = google
  index_endpoint    = google_vertex_ai_index_endpoint.vector_index_endpoint.id
  index             = google_vertex_ai_index.vector_index.id
  deployed_index_id = var.deployed_index_id

  # Corrected dynamic block for dedicated resources:
  dynamic "dedicated_resources" {
    for_each = var.deployed_index_resource_type == "dedicated" ? [1] : []
    content {
      min_replica_count = var.deployed_index_dedicated_min_replicas
      max_replica_count = var.deployed_index_dedicated_max_replicas
      machine_spec {  # machine_spec block
        machine_type = var.deployed_index_dedicated_machine_type
      }
    }
  }

  # Dynamic block for automatic resources configuration
  dynamic "automatic_resources" {
    for_each = var.deployed_index_resource_type == "automatic" ? [1] : []
    content {
      min_replica_count = var.deployed_index_automatic_min_replicas
      max_replica_count = var.deployed_index_automatic_max_replicas
    }
  }

  # Set reserved_ip_ranges directly, conditionally using a ternary operator:
 reserved_ip_ranges = var.deployed_index_reserved_ip_ranges == null ? null : var.deployed_index_reserved_ip_ranges

  timeouts {
    create = var.deployed_index_create_timeout
    update = var.deployed_index_update_timeout
    delete = var.deployed_index_delete_timeout
  }
}
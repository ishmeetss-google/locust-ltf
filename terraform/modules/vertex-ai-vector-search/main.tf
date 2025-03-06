# modules/vertex-ai-vector-search/main.tf

# -----------------------------------------------------------------------------
# Time Static Resource for Deployment Start
# -----------------------------------------------------------------------------
resource "time_static" "deployment_start" {
  triggers = {
    # This will be updated whenever any of the vector search resources change
    vector_search_config = jsonencode({
      index_id    = var.vector_search_index_id
      endpoint_id = var.endpoint_display_name
      deployed_id = var.deployed_index_id
    })
  }
}

# -----------------------------------------------------------------------------
# Vertex AI Index Resource
# -----------------------------------------------------------------------------
resource "google_vertex_ai_index" "vector_index" {
  project      = var.project_id
  count        = var.vector_search_index_id == null ? 1 : 0
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
      shard_size                  = var.index_shard_size
      feature_norm_type           = var.feature_norm_type

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
# Local for index ID handling
# -----------------------------------------------------------------------------
locals {
  index_id = var.vector_search_index_id != null ? var.vector_search_index_id : (
    length(google_vertex_ai_index.vector_index) > 0 ? google_vertex_ai_index.vector_index[0].id : null
  )
}

# -----------------------------------------------------------------------------
# Vertex AI Index Endpoint Resource
# -----------------------------------------------------------------------------
resource "google_vertex_ai_index_endpoint" "vector_index_endpoint" {
  project                 = var.project_id
  region                  = var.region
  display_name            = var.endpoint_display_name
  description             = var.endpoint_description
  labels                  = var.endpoint_labels
  public_endpoint_enabled = var.endpoint_public_endpoint_enabled

  # Only set network if PSC is not enabled
  network = var.endpoint_enable_private_service_connect ? null : var.endpoint_network

  # Only set private_service_connect_config if PSC is enabled
  dynamic "private_service_connect_config" {
    for_each = var.endpoint_enable_private_service_connect ? [1] : []
    content {
      enable_private_service_connect = true
      project_allowlist              = [var.project_id]
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

resource "random_id" "suffix" {
  byte_length = 4
}

resource "google_vertex_ai_index_endpoint_deployed_index" "deployed_vector_index" {
  depends_on     = [google_vertex_ai_index_endpoint.vector_index_endpoint]
  index_endpoint = google_vertex_ai_index_endpoint.vector_index_endpoint.id
  index          = local.index_id
  # Simplified deployed_index_id using random suffix
  deployed_index_id = "${var.deployed_index_id}_${random_id.suffix.hex}"

  # Optional PSC-related configurations
  enable_access_logging = var.enable_access_logging
  deployment_group      = var.deployment_group

  # Add authentication config if enabled
  dynamic "deployed_index_auth_config" {
    for_each = var.deployed_index_auth_enabled ? [1] : []
    content {
      auth_provider {
        audiences       = var.deployed_index_auth_audiences
        allowed_issuers = var.deployed_index_auth_allowed_issuers
      }
    }
  }

  # Rest of the configuration remains the same
  dynamic "dedicated_resources" {
    for_each = var.deployed_index_resource_type == "dedicated" ? [1] : []
    content {
      min_replica_count = var.deployed_index_dedicated_min_replicas
      max_replica_count = var.deployed_index_dedicated_max_replicas
      machine_spec {
        machine_type = var.deployed_index_dedicated_machine_type
      }
    }
  }

  dynamic "automatic_resources" {
    for_each = var.deployed_index_resource_type == "automatic" ? [1] : []
    content {
      min_replica_count = var.deployed_index_automatic_min_replicas
      max_replica_count = var.deployed_index_automatic_max_replicas
    }
  }

  reserved_ip_ranges = var.deployed_index_reserved_ip_ranges

  timeouts {
    create = var.deployed_index_create_timeout
    update = var.deployed_index_update_timeout
    delete = var.deployed_index_delete_timeout
  }
}

# modules/vertex-ai-vector-search/main.tf

# -----------------------------------------------------------------------------
# Vertex AI Index Resource
# -----------------------------------------------------------------------------
resource "google_vertex_ai_index" "vector_index" {
  project      = var.project_id
  count        = var.vector_search_index_id == null ? 1 : 0
  region       = var.region
  display_name = "${var.index_display_name}-${var.deployment_id}"
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
# Local for index ID handling and endpoint configuration
# -----------------------------------------------------------------------------
locals {
  # Index ID handling
  index_id = var.vector_search_index_id != null ? var.vector_search_index_id : (
    length(google_vertex_ai_index.vector_index) > 0 ? google_vertex_ai_index.vector_index[0].id : null
  )
  
  # Service connection handling
  is_public_endpoint = var.endpoint_public_endpoint_enabled
  is_psc_enabled = var.endpoint_enable_private_service_connect
  network_config = var.endpoint_enable_private_service_connect ? null : var.endpoint_network
}

# -----------------------------------------------------------------------------
# Vertex AI Index Endpoint Resource
# -----------------------------------------------------------------------------
resource "google_vertex_ai_index_endpoint" "vector_index_endpoint" {
  project                 = var.project_id
  region                  = var.region
  display_name            = "${var.endpoint_display_name}-${var.deployment_id}"
  description             = var.endpoint_description
  labels                  = var.endpoint_labels


  # Use different network settings based on access type
  public_endpoint_enabled = var.endpoint_public_endpoint_enabled

  # For VPC peering, use network parameter but not PSC config
  # For PSC, don't set network but add PSC config
  # For public, don't set either
  network = var.endpoint_enable_private_service_connect ? null : var.endpoint_network

  # Only set private_service_connect_config if PSC is enabled
  dynamic "private_service_connect_config" {
    for_each = local.is_psc_enabled ? [1] : []
    content {
      enable_private_service_connect = true
      project_allowlist              = [var.project_id]
    }
  }

    # Add dependency on VPC peering connection if it's provided
  depends_on = compact([
    var.vpc_peering_connection != null ? var.vpc_peering_connection : ""
  ])

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
  depends_on     = [google_vertex_ai_index_endpoint.vector_index_endpoint]
  index_endpoint = google_vertex_ai_index_endpoint.vector_index_endpoint.id
  index          = local.index_id
  # Simplified deployed_index_id using standardized deployment_id
  deployed_index_id = "${var.deployed_index_id}_${var.deployment_id}"

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

  # Resource allocation based on type
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
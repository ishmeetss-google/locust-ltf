project_id     = "vertex-platform"
region         = "us-central1"
project_number = "158892293228"

vector_search_index_id = "projects/vertex-platform/locations/us-central1/indexes/1688423249752358912"
index_dimensions = 768
endpoint_public_endpoint_enabled = true
deployed_index_resource_type = "automatic"
image = "us-central1-docker.pkg.dev/vertex-platform/locust-docker-repo/locust-load-test:LTF-20250303004016"

# Optional Vector Search Index configuration settings
# Uncomment and modify these as needed
# index_display_name = "my-vector-search-index"
# index_description = "Vector search index for embeddings"
# index_labels = { "environment" = "dev", "purpose" = "benchmarking" }
# index_approximate_neighbors_count = 150
# index_distance_measure_type = "DOT_PRODUCT_DISTANCE" # Options: COSINE_DISTANCE, EUCLIDEAN_DISTANCE, DOT_PRODUCT_DISTANCE
# feature_norm_type = "UNIT_L2_NORM" # Options: NONE, UNIT_L2_NORM
# index_algorithm_config_type = "TREE_AH_ALGORITHM" # Options: TREE_AH_ALGORITHM, BRUTE_FORCE_ALGORITHM
# index_tree_ah_leaf_node_embedding_count = 1000
# index_tree_ah_leaf_nodes_to_search_percent = 10
# index_update_method = "BATCH_UPDATE" # Options: BATCH_UPDATE, STREAM_UPDATE

# Optional Endpoint configuration settings
# endpoint_display_name = "my-vector-search-endpoint"
# endpoint_description = "Vector search endpoint for querying"
# endpoint_labels = { "environment" = "dev", "purpose" = "benchmarking" }
# endpoint_network = "projects/your-project/global/networks/your-vpc"
# endpoint_enable_private_service_connect = false
# endpoint_create_timeout = "60m"
# endpoint_update_timeout = "60m"
# endpoint_delete_timeout = "60m"

# Optional Deployed Index configuration settings
# deployed_index_id = "my-deployed-index"
# deployed_index_dedicated_machine_type = "e2-standard-4"
# deployed_index_dedicated_min_replicas = 2
# deployed_index_dedicated_max_replicas = 5
# deployed_index_dedicated_cpu_utilization_target = 0.7
# deployed_index_automatic_min_replicas = 2
# deployed_index_automatic_max_replicas = 5
# deployed_index_reserved_ip_ranges = ["ip-range-name-1", "ip-range-name-2"]
# deployed_index_create_timeout = "60m"
# deployed_index_update_timeout = "60m"
# deployed_index_delete_timeout = "60m"

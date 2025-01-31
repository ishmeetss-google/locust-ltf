# terraform.tfvars (Root - Example - Public Endpoint)

# --- Global Variables (from root variables.tf) ---
project_id = "whisper-test-378918" # Replace with your actual project ID
region     = "us-central1"         # Replace with your desired region

# --- Vertex AI Vector Search Module Variables (from modules/vertex-ai-vector-search/variables.tf) ---

# -- Cloud Storage Bucket (Existing) --
existing_bucket_name = "rag-repo-demart"                # Replace with your actual bucket name
embedding_data_path  = "github-repo/embeddings/dataset" # Replace with your embedding folder path

# -- Index Settings --
index_dimensions                           = 768               # default vablues
index_approximate_neighbors_count          = 150               # default vablues
index_distance_measure_type                = "COSINE_DISTANCE" # default vablues
feature_norm_type                          = "UNIT_L2_NORM"    # Add this line
index_algorithm_config_type                = "tree_ah_config"  # default vablues
index_tree_ah_leaf_node_embedding_count    = 500               # default vablues
index_tree_ah_leaf_nodes_to_search_percent = 8                 # default vablues
index_update_method                        = "BATCH_UPDATE"    # default vablues

# -- Endpoint Settings --
endpoint_public_endpoint_enabled        = true  # Enable public endpoint
endpoint_network                        = null  # No VPC Peering (public)
endpoint_enable_private_service_connect = false # No PSC (public)

# -- Deployed Index Settings --
deployed_index_resource_type          = "automatic" # Or "dedicated"
deployed_index_automatic_min_replicas = 2           # Only used if resource_type is "automatic"
deployed_index_automatic_max_replicas = 5           # Only used if resource_type is "automatic"

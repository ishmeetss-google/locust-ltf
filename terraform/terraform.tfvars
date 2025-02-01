# terraform.tfvars (Root - Example - Public Endpoint)

# --- Global Variables (from root variables.tf) ---
project_id = "whisper-test-378918" # Replace with your actual project ID
region     = "us-central1"         # Replace with your desired region

# --- Vertex AI Vector Search Module Variables (from modules/vertex-ai-vector-search/variables.tf) ---

# -- Cloud Storage Bucket (Existing) --
existing_bucket_name = "vector-load-testing" # Replace with your actual bucket name
embedding_data_path  = "dataset"             # Replace with your embedding folder path

# -- Index Settings --
index_dimensions                  = 768 # default vablues
index_approximate_neighbors_count = 150 # default vablues

# -- Endpoint Settings --
endpoint_public_endpoint_enabled = true # Enable public endpoint

# -- Deployed Index Settings --
deployed_index_resource_type = "automatic" # Or "dedicated"

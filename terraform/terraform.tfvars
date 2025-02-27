# terraform.tfvars (Root - Example - Public Endpoint)

# --- Global Variables (from root variables.tf) ---
project_id     = "zinc-forge-302418" # Replace with your actual project ID
project_number = 889751548103 # Replace with your actual Google cloud project number.
region         = "us-central1"         # Replace with your desired region

# --- Vertex AI Vector Search Module Variables (from modules/vertex-ai-vector-search/variables.tf) ---

# -- Cloud Storage Bucket (Existing) --
existing_bucket_name = "edp_test_data" # Replace with your actual bucket name
embedding_data_path  = "edp_test_data"             # Replace with your embedding folder path

# -- Index Settings --
index_dimensions                  = 768 # default vablues
index_approximate_neighbors_count = 150 # default vablues

# -- Endpoint Settings --
endpoint_public_endpoint_enabled = true # Enable public endpoint

# -- Deployed Index Settings --
deployed_index_resource_type = "automatic" # Or "dedicated"

# -- GKE Autopilot Settings --
image = "us-central1-docker.pkg.dev/zinc-forge-302418/locust-docker-repo/locust-load-test:LTF"

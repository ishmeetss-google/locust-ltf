project_id     = "vertex-vision-382819"
region         = "us-central1"
project_number = "599430110932"

existing_bucket_name = "vector_search_load_testing_5"
embedding_data_path = "dataset-laion-100m"
index_dimensions = 768
deployed_index_resource_type = "dedicated"
deployed_index_dedicated_machine_type = "e2-standard-16"
endpoint_public_endpoint_enabled = true
image = "us-central1-docker.pkg.dev/vertex-vision-382819/locust-docker-repo/locust-load-test:LTF-20250303165132"

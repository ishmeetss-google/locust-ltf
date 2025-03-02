# -----------------------------------------------------------------------------
# Outputs - Export important information
# -----------------------------------------------------------------------------
# output "index_endpoint_id" {
#   description = "The ID of the Index Endpoint"
#   value       = google_vertex_ai_index_endpoint.vector_index_endpoint.id
# }

# output "index_endpoint_public_endpoint" {
#   description = "The public endpoint of the Index Endpoint (if enabled)"
#   value       = google_vertex_ai_index_endpoint.vector_index_endpoint.public_endpoint_domain_name
#   sensitive   = false # Public endpoint is not considered sensitive, adjust if needed
# }

# output "deployed_index_id" {
#   description = "The ID of the Deployed Index"
#   value       = google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index.deployed_index_id
# }

# # output "index_id" {
# #   description = "The ID of the Vector Index"
# #   value       = local.index_id
# # }

# output "endpoint_public_url" {
#   description = "The public URL of the endpoint (if enabled)"
#   value       = var.endpoint_public_endpoint_enabled ? google_vertex_ai_index_endpoint.vector_index_endpoint.public_endpoint_domain_name : null
# }

# terraform/outputs.tf

output "vector_search_deployed_index_endpoint_id" {
  value       = module.vector_search.deployed_index_id
  description = "Vector Search Deployed Index Resource ID"
}

output "vector_search_index_endpoint_id" {
  value       = module.vector_search.index_endpoint_id
  description = "Vector Search Index Public Host (HTTPS)"
}

output "vector_search_deployed_index_endpoint_host" {
  value       = module.vector_search.index_endpoint_public_endpoint
  description = "Vector Search Index REST Endpoint (Domain Name)"
}

# Add an output for the proxy access instructions
output "locust_ui_access_instructions" {
  value = "Run: gcloud compute ssh ${google_compute_instance.nginx_proxy.name} --project ${var.project_id} --zone ${google_compute_instance.nginx_proxy.zone} -- -NL 8089:localhost:8089\nThen open http://localhost:8089 in your browser"
}
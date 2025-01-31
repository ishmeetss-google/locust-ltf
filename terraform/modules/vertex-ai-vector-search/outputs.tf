# -----------------------------------------------------------------------------
# Outputs - Export important information
# -----------------------------------------------------------------------------
output "index_endpoint_id" {
  description = "The ID of the Index Endpoint"
  value       = google_vertex_ai_index_endpoint.vector_index_endpoint.id
}

output "index_endpoint_public_endpoint" {
  description = "The public endpoint of the Index Endpoint (if enabled)"
  value       = google_vertex_ai_index_endpoint.vector_index_endpoint.public_endpoint_domain_name
  sensitive   = false # Public endpoint is not considered sensitive, adjust if needed
}

output "deployed_index_id" {
  description = "The ID of the Deployed Index"
  value       = google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index.deployed_index_id
}

output "index_id" {
  description = "The ID of the Vector Index"
  value       = google_vertex_ai_index.vector_index.id
}
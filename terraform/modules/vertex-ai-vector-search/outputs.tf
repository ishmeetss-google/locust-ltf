# -----------------------------------------------------------------------------
# Outputs - Export important information
# -----------------------------------------------------------------------------
output "index_endpoint_id" {
  description = "The ID of the created Vertex AI Index Endpoint"
  value       = google_vertex_ai_index_endpoint.vector_index_endpoint.id
}

output "index_endpoint_public_endpoint" {
  description = "The public endpoint domain name of the Index Endpoint"
  value       = google_vertex_ai_index_endpoint.vector_index_endpoint.public_endpoint_domain_name
  sensitive   = false # Public endpoint is not considered sensitive, adjust if needed
}

output "deployed_index_id" {
  description = "The ID of the deployed index"
  value       = google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index.deployed_index_id
}

output "index_id" {
  description = "The ID of the Vector Index"
  value       = local.index_id
}

output "endpoint_public_url" {
  description = "The public URL of the endpoint if public endpoint is enabled"
  value       = var.endpoint_public_endpoint_enabled ? google_vertex_ai_index_endpoint.vector_index_endpoint.public_endpoint_domain_name : null
}
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


# -----------------------------------------------------------------------------
# PSC-related outputs - will be null until PSC is enabled
# -----------------------------------------------------------------------------
output "private_endpoints" {
  description = "Raw private endpoints information for the deployed index (PSC)"
  value       = google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index.private_endpoints
}

output "service_attachment" {
  description = "The service attachment URI for PSC forwarding rule creation"
  value       = try(
    google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index.private_endpoints[0].service_attachment,
    null
  )
}

output "match_grpc_address" {
  description = "The private gRPC address for sending match requests"
  value       = try(
    google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index.private_endpoints[0].match_grpc_address,
    null
  )
}

output "psc_automated_endpoints" {
  description = "PSC automated endpoints information (populated after PSC automation)"
  value       = try(
    google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index.private_endpoints[0].psc_automated_endpoints,
    null
  )
}

# Convenience output for scripting - is PSC enabled in this deployment?
output "psc_enabled" {
  description = "Whether PSC is enabled for the endpoint"
  value       = var.endpoint_enable_private_service_connect
}
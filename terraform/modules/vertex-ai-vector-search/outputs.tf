# modules/vertex-ai-vector-search/outputs.tf
# -----------------------------------------------------------------------------
# Vector Search Core Outputs
# -----------------------------------------------------------------------------
output "index_id" {
  description = "The ID of the Vector Index"
  value       = local.index_id
}

output "endpoint_id" {
  description = "The ID of the created Vertex AI Index Endpoint"
  value       = google_vertex_ai_index_endpoint.vector_index_endpoint.id
}

output "deployed_index_id" {
  description = "The ID of the deployed index"
  value       = google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index.deployed_index_id
}

# -----------------------------------------------------------------------------
# Endpoint Access Outputs
# -----------------------------------------------------------------------------
output "public_endpoint_domain" {
  description = "The public endpoint domain name (if enabled)"
  value       = var.endpoint_public_endpoint_enabled ? google_vertex_ai_index_endpoint.vector_index_endpoint.public_endpoint_domain_name : null
}

# -----------------------------------------------------------------------------
# PSC-related outputs
# -----------------------------------------------------------------------------
output "psc_enabled" {
  description = "Whether PSC is enabled for the endpoint"
  value       = var.endpoint_enable_private_service_connect
}

output "service_attachment" {
  description = "The service attachment URI for PSC forwarding rule creation"
  value = try(
    var.endpoint_enable_private_service_connect ? google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index.private_endpoints[0].service_attachment : null,
    null
  )
}

output "match_grpc_address" {
  description = "The private gRPC address for sending match requests"
  value = try(
    var.endpoint_enable_private_service_connect ? google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index.private_endpoints[0].match_grpc_address : null,
    null
  )
}

output "psc_automated_endpoints" {
  description = "PSC automated endpoints information (if PSC automation is used)"
  value = try(
    var.endpoint_enable_private_service_connect ? google_vertex_ai_index_endpoint_deployed_index.deployed_vector_index.private_endpoints[0].psc_automated_endpoints : null,
    null
  )
}
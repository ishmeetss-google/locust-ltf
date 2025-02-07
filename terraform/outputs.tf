# -----------------------------------------------------------------------------
# Outputs - Export important information
# -----------------------------------------------------------------------------
output "index_endpoint_id" {
  description = "The ID of the Index Endpoint"
  value       = module.vector_search.index_endpoint_id
}

output "index_endpoint_public_endpoint" {
  description = "The public endpoint of the Index Endpoint (if enabled)"
  value       = module.vector_search.index_endpoint_public_endpoint
  sensitive   = false # Public endpoint is not considered sensitive, adjust if needed
}

output "deployed_index_id" {
  description = "The ID of the Deployed Index"
  value       = module.vector_search.deployed_index_id
}

output "index_id" {
  description = "The ID of the Vector Index"
  value       = module.vector_search.index_id
}

output "endpoint_public_url" {
  description = "The public URL of the endpoint (if enabled)"
  value       = var.endpoint_public_endpoint_enabled ? module.vector_search.index_endpoint_public_endpoint : null
}
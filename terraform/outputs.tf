# -----------------------------------------------------------------------------
# Outputs - Export important information
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# PSC-related outputs
# -----------------------------------------------------------------------------
output "vector_search_private_endpoints" {
  value       = module.vector_search.private_endpoints
  description = "Raw private endpoints information for the deployed index (PSC)"
}

output "vector_search_service_attachment" {
  value       = module.vector_search.service_attachment
  description = "The service attachment URI for PSC forwarding rule creation"
}

output "vector_search_match_grpc_address" {
  value       = module.vector_search.match_grpc_address
  description = "The private gRPC address for sending match requests"
}

output "vector_search_psc_automated_endpoints" {
  value       = module.vector_search.psc_automated_endpoints
  description = "PSC automated endpoints information (populated after PSC automation)"
}

output "vector_search_psc_enabled" {
  value       = module.vector_search.psc_enabled
  description = "Whether PSC is enabled for the endpoint"
}

# Add an output for the proxy access instructions
output "locust_ui_access_instructions" {
  value = "Run: gcloud compute ssh ${google_compute_instance.nginx_proxy.name} --project ${var.project_id} --zone ${google_compute_instance.nginx_proxy.zone} -- -NL 8089:localhost:8089\nThen open http://localhost:8089 in your browser"
}
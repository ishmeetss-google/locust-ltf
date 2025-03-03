# -----------------------------------------------------------------------------
# Outputs - Export important information
# -----------------------------------------------------------------------------

output "locust_master_web_ip" {
  description = "The IP address of the Locust master web LoadBalancer"
  value       = kubernetes_service.locust_master_web.status[0].load_balancer[0].ingress[0].ip
}
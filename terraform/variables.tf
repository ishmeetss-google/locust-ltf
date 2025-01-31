# variables.tf
variable "project_id" {
  type        = string
  description = "GCP Project ID"
  # No default - must be provided - User must set this
}

variable "region" {
  type        = string
  description = "GCP Region for Vertex Search"
  default     = "us-central1" # Default region, can be overridden
}
variable "project_id" {
  type        = string
  description = "The ID of the Google Cloud project where resources will be created."
}

variable "region" {
  type        = string
  description = "The Google Cloud region where resources will be created."
  default     = "us-central1"
}

variable "worker_replicas" {
  type        = number
  description = "Number of Locust worker replicas."
  default     = 5
}
variable "project_id" {
    type = string
    description = "The ID of the Google Cloud project where resources will be created."
    default = "email2podcast"
}

variable "region" {
    type = string
    description = "The Google Cloud region where resources will be created."
    default = "us-central1"
}

variable "kubernetes_cluster_name" {
  type        = string
  description = "The name of the Kubernetes cluster."
}

variable "kubernetes_cluster_location" {
  type        = string
  description = "The location of the Kubernetes cluster."
}

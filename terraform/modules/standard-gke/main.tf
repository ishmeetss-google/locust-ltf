terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.18.1"
    }
  }
}

resource "google_service_account" "service_account" {
  account_id   = "standard-terraform-ltf-account"
  display_name = "standard-terraform-ltf-service-account"
  project = var.project_id
}

resource "google_project_iam_custom_role" "ltf-custom-role" {
  project     = var.project_id
  role_id     = "standard_ltf_custom_role"
  title       = "LTF Custom Role"
  description = ""
  permissions = ["aiplatform.indexEndpoints.queryVectors"]
}


resource "google_project_iam_binding" "project" {
  project = var.project_id
  role    = google_project_iam_custom_role.ltf-custom-role.id

  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_project_iam_binding" "project_2" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_project_iam_binding" "project_3" {
  project = var.project_id
  role    = "roles/reader"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_container_cluster" "primary" {
  name     = "standard-gke-terraform-cluster"
  location = "us-central1"
  project  = var.project_id
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection = false
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "standard-terraform-node-pool"
  location   = "us-central1"
  project    = var.project_id
  cluster    = google_container_cluster.primary.name
  node_count = 3

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.service_account.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

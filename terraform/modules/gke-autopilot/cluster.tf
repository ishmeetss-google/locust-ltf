terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.18.1"
    }
  }
}

resource "google_service_account" "service_account" {
  account_id   = "ltf-service-account"
  display_name = "ltf-service-account"
  project      = var.project_id
}

resource "google_project_iam_binding" "artifactregistry_reader_binding" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_project_iam_binding" "container_default_node_service_account_binding" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_container_cluster" "ltf_autopilot_cluster" {
  name                = "ltf-autopilot-cluster"
  project             = var.project_id
  location            = var.region
  enable_autopilot    = true
  deletion_protection = false
  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.service_account.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }
}

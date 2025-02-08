terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.18.1"
    }
  }
}

resource "google_service_account" "service_account" {
  account_id   = "terraform-ltf-service-account"
  display_name = "terraform-ltf-service-account"
  project = var.project_id
}

resource "google_project_iam_custom_role" "ltf-custom-role" {
  project     = var.project_id
  role_id     = "ltf_custom_role"
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

resource "google_container_cluster" "primary" {
  name     = "terraform-ltf-cluster"
  project  = var.project_id
  location = var.region
  enable_autopilot = true
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

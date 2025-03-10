data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.ltf_autopilot_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.ltf_autopilot_cluster.master_auth[0].cluster_ca_certificate)

  ignore_annotations = [
    "^autopilot\\.gke\\.io\\/.*",
    "^cloud\\.google\\.com\\/.*"
  ]
}

# First binding - just for the GCP service account
resource "google_project_iam_binding" "aiplatform_viewer_binding" {
  project = var.project_id
  role    = "roles/aiplatform.viewer"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

# Second binding - for the Kubernetes service account, applied later
# You can comment this out initially and apply it after the cluster is fully ready
resource "google_project_iam_member" "aiplatform_viewer_k8s_binding" {
  project = var.project_id
  role    = "roles/aiplatform.viewer"
  member  = "principal://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/default/sa/default"

  depends_on = [
    google_container_cluster.ltf_autopilot_cluster,
    # Add a time delay or another indicator that the cluster is fully ready
  ]
}
resource "kubernetes_config_map" "locust_config" {
  metadata {
    name = "locust-config"
  }

  data = {
    "locust_config.env" = file("${path.module}/../../../config/locust_config.env")
  }
}

resource "kubernetes_deployment" "locust_master" {
  metadata {
    name = "locust-master"
  }
  spec {
    selector {
      match_labels = {
        app = "locust-master"
      }
    }
    template {
      metadata {
        labels = {
          app = "locust-master"
        }
      }
      spec {
        automount_service_account_token = true
        volume {
          name = "locust-config"
          config_map {
            name         = kubernetes_config_map.locust_config.metadata[0].name
            default_mode = "0644"
          }
        }
        container {
          image = var.image
          name  = "locust-master"
          volume_mount {
            name       = "locust-config"
            mount_path = "/tasks/locust_config.env"
            sub_path   = "locust_config.env"
          }
          args = ["-f", "/tasks/locust.py", "--master", "--class-picker"]
          port {
            container_port = 8089
            name           = "loc-master-web"
          }
          port {
            container_port = 5557
            name           = "loc-master-p1"
          }
          port {
            container_port = 5558
            name           = "loc-master-p2"
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "locust_worker" {
  metadata {
    name = "locust-worker"
  }
  spec {
    selector {
      match_labels = {
        app = "locust-worker"
      }
    }
    template {
      metadata {
        labels = {
          app = "locust-worker"
        }
      }
      spec {
        automount_service_account_token = true

        volume {
          name = "locust-config"
          config_map {
            name         = kubernetes_config_map.locust_config.metadata[0].name
            default_mode = "0644"
          }
        }
        container {
          image = var.image
          name  = "locust-worker"
          volume_mount {
            name       = "locust-config"
            mount_path = "/tasks/locust_config.env"
            sub_path   = "locust_config.env"
          }
          args = ["-f", "/tasks/locust.py", "--worker", "--master-host", "locust-master"]
          resources {
            requests = {
              cpu = "1000m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "locust_master" {
  metadata {
    name = "locust-master"
    labels = {
      app = "locust-master"
    }
  }
  spec {
    selector = {
      app = "locust-master"
    }
    port {
      port        = 8089
      target_port = "loc-master-web"
      name        = "loc-master-web"
    }
    port {
      port        = 5557
      target_port = "loc-master-p1"
      name        = "loc-master-p1"
    }
    port {
      port        = 5558
      target_port = "loc-master-p2"
      name        = "loc-master-p2"
    }
  }
}

resource "kubernetes_service" "locust_master_web" {
  metadata {
    name = "locust-master-web"
    annotations = {
      "networking.gke.io/load-balancer-type" = "Internal"
    }
    labels = {
      app = "locust-master"
    }
  }
  spec {
    selector = {
      app = "locust-master"
    }
    port {
      port        = 8089
      target_port = "loc-master-web"
      name        = "loc-master-web"
    }
    type = "LoadBalancer"
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "locust_worker_autoscaler" {
  metadata {
    name = "locust-worker-autoscaler"
  }

  spec {
    min_replicas = 1
    max_replicas = 1000

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "locust-worker"
    }
    target_cpu_utilization_percentage = 50
  }
}

resource "google_container_cluster" "locust_cluster" {
  name     = "locust-cluster"
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

resource "kubernetes_deployment" "locust_master" {
  metadata {
    name      = "locust-master"
    namespace = "default"
  }
  spec {
    replicas = 1
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
        container {
          image = "us-central1-docker.pkg.dev/email2podcast/ishmeetss-locust-docker-repo/locust-image:LTF"
          name  = "locust-master"
          args  = ["-f", "/tasks/public_http_query.py", "--master", "--class-picker"]
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
    name      = "locust-worker"
    namespace = "default"
  }
  spec {
    replicas = var.worker_replicas
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
        container {
          image = "us-central1-docker.pkg.dev/email2podcast/ishmeetss-locust-docker-repo/locust-image:LTF"
          name  = "locust-worker"
          args  = ["-f", "/tasks/public_http_query.py", "--worker", "--master-host", "locust-master"]
        }
      }
    }
  }
}

resource "kubernetes_service" "locust_master" {
  metadata {
    name      = "locust-master"
    namespace = "default"
  }
  spec {
    selector = {
      app = "locust-master"
    }
    port {
      port        = 8089
      target_port = "loc-master-web"
    }
    port {
      port        = 5557
      target_port = "loc-master-p1"
    }
    port {
      port        = 5558
      target_port = "loc-master-p2"
    }
    type = "LoadBalancer"
  }
}
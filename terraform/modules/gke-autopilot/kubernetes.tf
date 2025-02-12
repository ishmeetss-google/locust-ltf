data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)

  ignore_annotations = [
    "^autopilot\\.gke\\.io\\/.*",
    "^cloud\\.google\\.com\\/.*"
  ]
}

resource "kubernetes_deployment_v1" "locust_master" {
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

resource "kubernetes_deployment_v1" "locust_worker" {
  metadata {
    name      = "locust-worker"
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
        container {
          image = "us-central1-docker.pkg.dev/email2podcast/ishmeetss-locust-docker-repo/locust-image:LTF"
          name  = "locust-worker"
          args  = ["-f", "/tasks/public_http_query.py", "--worker", "--master-host", "locust-master"]
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "locust_master" {
  metadata {
    name      = "locust-master"
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
      name  = "loc-master-web"
    }
    port {
      port        = 5557
      target_port = "loc-master-p1"
      name  = "loc-master-p1"
    }
    port {
      port        = 5558
      target_port = "loc-master-p2"
      name  = "loc-master-p2"
    }
  }
}

resource "kubernetes_service_v1" "locust_master_web" {
  metadata {
    name      = "locust-master-web"
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
      name = "loc-master-web"
    }
    type = "LoadBalancer"
  }
}

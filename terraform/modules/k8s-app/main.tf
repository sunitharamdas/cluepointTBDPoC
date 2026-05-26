terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

locals {
  # Labels applied to every resource in this module
  common_labels = {
    "app.kubernetes.io/name"       = var.app_name
    "app.kubernetes.io/instance"   = "${var.app_name}-${var.namespace}"
    "app.kubernetes.io/managed-by" = "terraform"
    "environment"                  = var.namespace
  }

  # Subset used as pod selector – must stay stable across updates
  selector_labels = {
    "app.kubernetes.io/name"     = var.app_name
    "app.kubernetes.io/instance" = "${var.app_name}-${var.namespace}"
  }
}

# ---------------------------------------------------------------------------
# Namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "this" {
  metadata {
    name   = var.namespace
    labels = local.common_labels
  }
}

# ---------------------------------------------------------------------------
# ConfigMap – non-secret runtime configuration
# ---------------------------------------------------------------------------
resource "kubernetes_config_map" "this" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.common_labels
  }

  data = var.env_vars
}

# ---------------------------------------------------------------------------
# Deployment
# ---------------------------------------------------------------------------
resource "kubernetes_deployment" "this" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.common_labels
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = local.selector_labels
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "1"
        max_unavailable = "0" # zero-downtime: bring new pod up before removing old one
      }
    }

    template {
      metadata {
        labels = local.common_labels
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
        }

        container {
          name  = var.app_name
          image = var.image

          port {
            container_port = var.container_port
            protocol       = "TCP"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.this.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 10
            period_seconds        = 15
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            failure_threshold     = 3
          }
        }
      }
    }
  }

  # Allow external tools (e.g. kubectl rollout) to add annotations without
  # triggering a Terraform diff on next apply.
  lifecycle {
    ignore_changes = [
      spec[0].template[0].metadata[0].annotations,
    ]
  }
}

# ---------------------------------------------------------------------------
# Service (ClusterIP – only reachable inside the cluster; Ingress exposes it)
# ---------------------------------------------------------------------------
resource "kubernetes_service" "this" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.common_labels
  }

  spec {
    selector = local.selector_labels
    type     = "ClusterIP"

    port {
      port        = 80
      target_port = var.container_port
      protocol    = "TCP"
    }
  }
}

# ---------------------------------------------------------------------------
# Ingress (nginx ingress controller assumed; swap annotations for other classes)
# ---------------------------------------------------------------------------
resource "kubernetes_ingress_v1" "this" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.common_labels
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    ingress_class_name = var.ingress_class

    rule {
      host = var.ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.this.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

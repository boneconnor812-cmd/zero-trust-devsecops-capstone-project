# =============================================================================
# Juice Shop Deployment — managed by Terraform
# Replaces the manual kubectl-applied manifest from Week 1
# =============================================================================

resource "kubernetes_namespace" "juice_shop" {
  metadata {
    name = "juice-shop"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_deployment" "juice_shop" {
  metadata {
    name      = "juice-shop"
    namespace = kubernetes_namespace.juice_shop.metadata[0].name
    labels = {
      "app"                          = "juice-shop"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "juice-shop"
      }
    }

    template {
      metadata {
        labels = {
          app = "juice-shop"
        }
      }

      spec {
        # Use the dedicated least-privilege ServiceAccount
        service_account_name = kubernetes_service_account.juice_shop.metadata[0].name

        # Belt and suspenders — also disable token mounting at the pod level
        automount_service_account_token = false

        container {
          name  = "juice-shop"
          image = "bkimminich/juice-shop:latest"

          port {
            container_port = 3000
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "juice_shop" {
  metadata {
    name      = "juice-shop"
    namespace = kubernetes_namespace.juice_shop.metadata[0].name
    labels = {
      "app"                          = "juice-shop"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    selector = {
      app = "juice-shop"
    }

    port {
      port        = 3000
      target_port = 3000
      node_port   = 30000
    }

    type = "NodePort"
  }
}

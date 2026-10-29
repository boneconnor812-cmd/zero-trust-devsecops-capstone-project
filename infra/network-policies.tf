# Default-deny all ingress and egress in the juice-shop namespace.
# With policy_types declared but NO ingress/egress rules,
# Kubernetes blocks everything not explicitly allowed by another policy.
# Maps to: NIST AC-4 (Information Flow Enforcement), SC-7 (Boundary Protection)
resource "kubernetes_network_policy" "default_deny_juice_shop" {
  metadata {
    name      = "default-deny-all"
    namespace = "juice-shop"
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

# Allow inbound HTTP on port 3000 to Juice Shop pods only.
# This is the only ingress path into the application.
# Maps to: NIST AC-4, SC-7
resource "kubernetes_network_policy" "allow_juice_shop_ingress" {
  metadata {
    name      = "allow-juice-shop-ingress"
    namespace = "juice-shop"
  }

  spec {
    pod_selector {
      match_labels = {
        app = "juice-shop"
      }
    }

    ingress {
      ports {
        port     = "3000"
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}

# Allow DNS egress for all pods in the namespace so they can
# resolve internal service names via CoreDNS. No other egress
# is permitted — a compromised container cannot reach the internet.
# Maps to: NIST SC-7 (Boundary Protection), SI-4 (System Monitoring)
resource "kubernetes_network_policy" "allow_juice_shop_dns" {
  metadata {
    name      = "allow-juice-shop-dns"
    namespace = "juice-shop"
  }

  spec {
    pod_selector {}

    egress {
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }

    policy_types = ["Egress"]
  }
}

# Allow egress to Juice Shop on port 3000 within the namespace.
# This lets internal pods (and ArgoCD health checks) reach the application.
# Combined with default-deny, only DNS and this port are allowed out —
# everything else (internet, other namespaces) is blocked.
# Maps to: NIST AC-4 (Information Flow Enforcement)
resource "kubernetes_network_policy" "allow_internal_egress" {
  metadata {
    name      = "allow-internal-egress-3000"
    namespace = "juice-shop"
  }

  spec {
    pod_selector {}

    egress {
      to {
        pod_selector {
          match_labels = {
            app = "juice-shop"
          }
        }
      }
      ports {
        port     = "3000"
        protocol = "TCP"
      }
    }

    policy_types = ["Egress"]
  }
}

# =============================================================================
# Week 7 — RBAC & Least-Privilege Identity
# NIST SP 800-53: AC-6 (Least Privilege), AC-2 (Account Management)
# DoD Zero Trust Pillar: Identity
# =============================================================================

# Dedicated ServiceAccount for Juice Shop
# Why: Every workload gets its own identity instead of sharing the namespace default.
# This lets us set permissions per-workload and audit who did what.
resource "kubernetes_service_account" "juice_shop" {
  metadata {
    name      = "juice-shop-sa"
    namespace = "juice-shop"
    labels = {
      "app"                          = "juice-shop"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # Disable automatic mounting of the API token into pods.
  # Juice Shop is a web app — it never needs to talk to the Kubernetes API.
  # If an attacker compromises the app, there's no token to steal.
  automount_service_account_token = false
}

# Role with zero permissions — exists only to document that Juice Shop
# intentionally has no Kubernetes API access. If we ever need to grant it
# something (like reading a ConfigMap), we add a rule here instead of
# giving it the default SA's permissions.
resource "kubernetes_role" "juice_shop" {
  metadata {
    name      = "juice-shop-role"
    namespace = "juice-shop"
    labels = {
      "app"                          = "juice-shop"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get"]
  }

  # Intentionally empty — Juice Shop needs no API permissions.
  # This role exists so the binding is in place if we ever need to
  # grant minimal permissions later.
}

# Bind the empty role to the ServiceAccount
resource "kubernetes_role_binding" "juice_shop" {
  metadata {
    name      = "juice-shop-binding"
    namespace = "juice-shop"
    labels = {
      "app"                          = "juice-shop"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.juice_shop.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.juice_shop.metadata[0].name
    namespace = "juice-shop"
  }
}

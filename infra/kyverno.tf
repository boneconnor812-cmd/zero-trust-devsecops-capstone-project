# =============================================================================
# Week 8 — Kyverno Admission Controller
# NIST SP 800-53: CM-7 (Least Functionality)
# DoD Zero Trust Pillar: Application
# =============================================================================

resource "helm_release" "kyverno" {
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno"
  chart      = "kyverno"
  namespace  = "kyverno"

  create_namespace = true

  set {
    name  = "replicaCount"
    value = "1"
  }

  set {
    name  = "admissionController.replicas"
    value = "1"
  }
}

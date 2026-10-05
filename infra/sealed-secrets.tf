# =============================================================================
# Week 8 — Sealed Secrets
# NIST SP 800-53: SC-28 (Protection of Information at Rest)
# DoD Zero Trust Pillar: Data
# =============================================================================

resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  namespace  = "kube-system"
  version    = "2.16.2"

  set {
    name  = "fullnameOverride"
    value = "sealed-secrets-controller"
  }
}

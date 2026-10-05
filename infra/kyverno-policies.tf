# =============================================================================
# Kyverno Cluster Policies
# These policies apply to ALL namespaces (except kube-system and kyverno).
# They enforce security baselines at admission time — before pods ever run.
# =============================================================================

# Policy 1: Block privileged containers
resource "kubernetes_manifest" "policy_disallow_privileged" {
  depends_on = [helm_release.kyverno]

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "disallow-privileged-containers"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
      annotations = {
        "policies.kyverno.io/title"       = "Disallow Privileged Containers"
        "policies.kyverno.io/category"    = "Pod Security"
        "policies.kyverno.io/severity"    = "high"
        "policies.kyverno.io/description" = "Blocks containers from running in privileged mode, which would give full host access."
      }
    }
    spec = {
      validationFailureAction = "Enforce"
      background              = true
      rules = [
        {
          name = "deny-privileged"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Pod"]
                }
              }
            ]
          }
          exclude = {
            any = [
              {
                resources = {
                  namespaces = ["kube-system", "kyverno"]
                }
              }
            ]
          }
          validate = {
            message = "Privileged containers are not allowed. Remove securityContext.privileged or set it to false."
            pattern = {
              spec = {
                containers = [
                  {
                    "=(securityContext)" = {
                      "=(privileged)" = false
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }
}

# Policy 2: Require resource limits
resource "kubernetes_manifest" "policy_require_resource_limits" {
  depends_on = [helm_release.kyverno]

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-resource-limits"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
      annotations = {
        "policies.kyverno.io/title"       = "Require Resource Limits"
        "policies.kyverno.io/category"    = "Best Practices"
        "policies.kyverno.io/severity"    = "medium"
        "policies.kyverno.io/description" = "Requires all containers to specify CPU and memory limits."
      }
    }
    spec = {
      validationFailureAction = "Audit"
      background              = true
      rules = [
        {
          name = "check-resource-limits"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Pod"]
                }
              }
            ]
          }
          exclude = {
            any = [
              {
                resources = {
                  namespaces = ["kube-system", "kyverno"]
                }
              }
            ]
          }
          validate = {
            message = "CPU and memory limits are required for all containers."
            pattern = {
              spec = {
                containers = [
                  {
                    resources = {
                      limits = {
                        memory = "?*"
                        cpu    = "?*"
                      }
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }
}

# Policy 3: Require non-root containers
resource "kubernetes_manifest" "policy_require_run_as_nonroot" {
  depends_on = [helm_release.kyverno]

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-run-as-nonroot"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
      annotations = {
        "policies.kyverno.io/title"       = "Require Run as Non-Root"
        "policies.kyverno.io/category"    = "Pod Security"
        "policies.kyverno.io/severity"    = "medium"
        "policies.kyverno.io/description" = "Requires containers to run as a non-root user."
      }
    }
    spec = {
      validationFailureAction = "Audit"
      background              = true
      rules = [
        {
          name = "check-nonroot"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Pod"]
                }
              }
            ]
          }
          exclude = {
            any = [
              {
                resources = {
                  namespaces = ["kube-system", "kyverno"]
                }
              }
            ]
          }
          validate = {
            message = "Containers must run as non-root. Set securityContext.runAsNonRoot to true."
            pattern = {
              spec = {
                containers = [
                  {
                    securityContext = {
                      runAsNonRoot = true
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }
}

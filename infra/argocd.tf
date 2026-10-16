# =============================================================================
# Week 10 — ArgoCD GitOps Continuous Delivery
# =============================================================================
# WHY: GitOps closes the loop between CI (GitHub Actions) and CD (cluster).
#      Instead of manually running kubectl/terraform to deploy, ArgoCD
#      watches your Git repo and automatically syncs the cluster state to
#      match what's defined in code.
#
# HOW: ArgoCD runs a controller in the cluster that:
#      1. Polls your Git repo on an interval (default 3 minutes)
#      2. Compares the manifests in Git to what's running in K8s
#      3. If they differ (drift), it can auto-sync or alert you
#
# ZERO TRUST: This enforces the Automation & Orchestration pillar.
#             All changes flow through Git (audit trail) → CI pipeline
#             (scanned/signed) → ArgoCD (deployed). No human needs direct
#             cluster access to deploy — the Git repo IS the control plane.
#
# NIST SP 800-53: CM-2  (Baseline Configuration)
#                 CM-3  (Configuration Change Control)
#                 CM-6  (Configuration Settings)
#                 SA-10 (Developer Configuration Management)
# DoD ZT Pillar:  Automation & Orchestration
# =============================================================================

# --- ArgoCD Helm Release ---
# ArgoCD runs as a set of microservices: the API server (UI + CLI),
# the repo server (clones Git repos), the application controller
# (does the sync), and Redis (caching).
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  # Expose the ArgoCD web UI via NodePort so you can access it
  # from your browser at http://<VM-IP>:30080
  set {
    name  = "server.service.type"
    value = "NodePort"
  }
  set {
    name  = "server.service.nodePortHttp"
    value = "30080"
  }

  # Disable TLS on the ArgoCD server itself — we're in a lab
  # and accessing via HTTP. In production you'd terminate TLS
  # at an ingress controller or load balancer.
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  # Resource limits — keep ArgoCD lean on our single-node cluster
  # The server is the UI/API component
  set {
    name  = "server.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "server.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "server.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "server.resources.limits.memory"
    value = "256Mi"
  }

  # The repo server clones your Git repos and renders manifests
  set {
    name  = "repoServer.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "repoServer.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "repoServer.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "repoServer.resources.limits.memory"
    value = "256Mi"
  }

  # The application controller watches the cluster and does the syncing
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "controller.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "controller.resources.limits.memory"
    value = "256Mi"
  }

  # Redis caching — minimal resources for lab use
  set {
    name  = "redis.resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "redis.resources.requests.memory"
    value = "64Mi"
  }
  set {
    name  = "redis.resources.limits.cpu"
    value = "200m"
  }
  set {
    name  = "redis.resources.limits.memory"
    value = "128Mi"
  }
}

# --- ArgoCD Application ---
# This is the key GitOps resource. It tells ArgoCD:
#   "Watch THIS repo, THIS path, and sync it to THIS namespace."
#
# Once created, ArgoCD will:
#   1. Clone your repo
#   2. Read the manifests in k8s-manifests/
#   3. Apply them to the juice-shop namespace
#   4. Continuously monitor for drift
resource "kubectl_manifest" "argocd_app" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: juice-shop
      namespace: argocd
    spec:
      project: default

      # SOURCE — where to pull manifests from
      source:
        repoURL: https://github.com/boneconnor812-cmd/zero-trust-devsecops-capstone-project.git
        targetRevision: main
        path: k8s-manifests

      # DESTINATION — where to deploy them in the cluster
      destination:
        server: https://kubernetes.default.svc
        namespace: juice-shop

      # SYNC POLICY — how ArgoCD handles drift
      syncPolicy:
        automated:
          # prune: delete resources from K8s if they're removed from Git
          prune: true
          # selfHeal: revert manual changes — if someone kubectl-edits
          # something, ArgoCD puts it back to match Git
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd]
}

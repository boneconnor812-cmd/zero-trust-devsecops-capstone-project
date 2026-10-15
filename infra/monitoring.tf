# =============================================================================
# Week 9 — Loki + Promtail + Grafana Monitoring Stack
# =============================================================================
# WHY: Detective controls (Falco) generate alerts, but alerts without a
#      centralized place to collect, search, and visualize them are useless.
#      In a real SOC (Security Operations Center), analysts need dashboards
#      and searchable logs to investigate incidents.
#
# THE STACK:
#   Promtail → Loki → Grafana
#   (collect)   (store)  (visualize)
#
#   Promtail: DaemonSet that tails container logs on each node and ships
#             them to Loki. Think of it as the "log forwarder."
#   Loki:     Log aggregation system by Grafana Labs. Unlike Elasticsearch,
#             it only indexes LABELS (pod name, namespace, etc.), not the
#             full text. This makes it much lighter on resources.
#   Grafana:  Web dashboard for querying and visualizing logs and metrics.
#
# NIST SP 800-53: AU-2  (Audit Events)
#                 AU-3  (Content of Audit Records)
#                 AU-6  (Audit Review, Analysis, and Reporting)
#                 AU-12 (Audit Record Generation)
# DoD ZT Pillar:  Visibility & Analytics
# =============================================================================

# --- Loki (Log Storage) ---
# Deployed in single-binary mode ("monolithic") for simplicity on a
# single-node cluster. Production would use microservices mode with
# separate read/write/backend components.
resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  namespace        = "monitoring"
  create_namespace = true

  # Single-binary mode — all Loki components in one process.
  # Perfect for dev/lab, too simple for production.
  set {
    name  = "deploymentMode"
    value = "SingleBinary"
  }

  # Single replica — we only have one node
  set {
    name  = "singleBinary.replicas"
    value = "1"
  }

  # Disable the default gateway (nginx) — unnecessary overhead
  # for a single-node lab cluster
  set {
    name  = "gateway.enabled"
    value = "false"
  }

  # Disable multi-tenancy — not needed for a lab environment
  set {
    name  = "loki.auth_enabled"
    value = "false"
  }

  # Use filesystem storage instead of S3/GCS — good for a lab,
  # production would use object storage for durability
  set {
    name  = "loki.storage.type"
    value = "filesystem"
  }

  # Resource limits — keep Loki lean
  set {
    name  = "singleBinary.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "singleBinary.resources.requests.memory"
    value = "256Mi"
  }
  set {
    name  = "singleBinary.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "singleBinary.resources.limits.memory"
    value = "512Mi"
  }

  # Disable backend and read components (only needed in distributed mode)
  set {
    name  = "backend.replicas"
    value = "0"
  }
  set {
    name  = "read.replicas"
    value = "0"
  }
  set {
    name  = "write.replicas"
    value = "0"
  }

  # Schema config — tells Loki how to store and index chunks.
  # tsdb is the modern storage engine (replaces boltdb-shipper).
  set {
    name  = "loki.schemaConfig.configs[0].from"
    value = "2024-01-01"
  }
  set {
    name  = "loki.schemaConfig.configs[0].store"
    value = "tsdb"
  }
  set {
    name  = "loki.schemaConfig.configs[0].object_store"
    value = "filesystem"
  }
  set {
    name  = "loki.schemaConfig.configs[0].schema"
    value = "v13"
  }
  set {
    name  = "loki.schemaConfig.configs[0].index.prefix"
    value = "loki_index_"
  }
  set {
    name  = "loki.schemaConfig.configs[0].index.period"
    value = "24h"
  }
  set {
    name = "loki.commonConfig.replication_factor"
    value = "1"
  }
}

# --- Promtail (Log Collector) ---
# Runs as a DaemonSet — one per node — and reads container logs
# from /var/log/pods on the host filesystem, then ships them to Loki.
# It automatically discovers pods via the Kubernetes API and adds
# labels (namespace, pod name, container name) to each log line.
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  namespace  = "monitoring"

  # Tell Promtail where to send logs — Loki's HTTP endpoint
  set {
    name  = "config.clients[0].url"
    value = "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
  }

  # Resource limits
  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }
  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }

  depends_on = [helm_release.loki]
}

# --- Grafana (Visualization) ---
# Web UI for querying Loki logs and building dashboards.
# We pre-configure the Loki data source so it's ready to use
# immediately — no manual setup needed.
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "monitoring"

  # Admin credentials — in production you'd use Sealed Secrets for this,
  # but for a lab we set them directly
  set {
    name  = "adminUser"
    value = "admin"
  }
  set {
    name  = "adminPassword"
    value = "zerotrust2024"
  }

  # Pre-configure Loki as a data source so Grafana is ready to query
  # logs immediately after deployment. No manual clicking through the UI.
  set {
    name  = "datasources.datasources\\.yaml.apiVersion"
    value = "1"
  }
  set {
    name  = "datasources.datasources\\.yaml.datasources[0].name"
    value = "Loki"
  }
  set {
    name  = "datasources.datasources\\.yaml.datasources[0].type"
    value = "loki"
  }
  set {
    name  = "datasources.datasources\\.yaml.datasources[0].url"
    value = "http://loki.monitoring.svc.cluster.local:3100"
  }
  set {
    name  = "datasources.datasources\\.yaml.datasources[0].access"
    value = "proxy"
  }
  set {
    name  = "datasources.datasources\\.yaml.datasources[0].isDefault"
    value = "true"
  }

  # Expose Grafana via NodePort so you can access it from your
  # host machine's browser. Port 30300 on the VM's IP.
  set {
    name  = "service.type"
    value = "NodePort"
  }
  set {
    name  = "service.nodePort"
    value = "30300"
  }

  # Resource limits
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "resources.requests.memory"
    value = "256Mi"
  }
  set {
    name  = "resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "resources.limits.memory"
    value = "512Mi"
  }

  # Persistence — store Grafana dashboards and config on disk
  # so they survive pod restarts
  set {
    name  = "persistence.enabled"
    value = "true"
  }
  set {
    name  = "persistence.size"
    value = "1Gi"
  }

  depends_on = [helm_release.loki]
}

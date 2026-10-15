# =============================================================================
# Week 9 — Falco Runtime Threat Detection
# =============================================================================
# WHY: Weeks 6-8 were preventive controls (block bad things from happening).
#      Falco is a DETECTIVE control — it watches what containers actually DO
#      at runtime by hooking into the Linux kernel via eBPF.
#
# HOW: Falco monitors every syscall (file opens, process spawns, network
#      connections) and fires alerts when it sees suspicious behavior.
#      Think of it as a security camera for your cluster's kernel activity.
#
# NIST SP 800-53: SI-4  (Information System Monitoring)
#                 AU-2  (Audit Events)
#                 AU-12 (Audit Generation)
# DoD ZT Pillar:  Visibility & Analytics
# =============================================================================

# --- Falco Helm Release ---
# Falco runs as a DaemonSet — one instance per node — because it needs
# direct access to the kernel on each machine to monitor syscalls.
resource "helm_release" "falco" {
  name             = "falco"
  repository       = "https://falcosecurity.github.io/charts"
  chart            = "falco"
  namespace        = "falco"
  create_namespace = true

  # Use the modern eBPF driver instead of the kernel module.
  # eBPF is safer (runs in a sandbox) and doesn't require kernel headers
  # to be installed on the node. k3s works well with eBPF.
  set {
    name  = "driver.kind"
    value = "modern_ebpf"
  }

  # Resource limits — keep Falco lean on our single-node cluster
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

  # Enable JSON output so Loki/Grafana can parse alerts
  set {
    name  = "falco.json_output"
    value = "true"
  }

  # Log to stdout so Promtail picks up alerts automatically
  set {
    name  = "falco.stdout_output.enabled"
    value = "true"
  }

  # Falcosidekick forwards alerts to external systems.
  # We enable it so alerts flow into Loki via stdout, and
  # we could later add Slack/email webhooks.
  set {
    name  = "falcosidekick.enabled"
    value = "true"
  }
  set {
    name  = "falcosidekick.replicaCount"
    value = "1"
  }
}

# --- Custom Falco Rules ---
# Falco ships with ~80+ default rules, but we add custom ones
# that align with our Zero Trust security posture.
# These rules must be created AFTER Falco is installed.
resource "kubernetes_config_map" "falco_custom_rules" {
  metadata {
    name      = "falco-custom-rules"
    namespace = "falco"
    labels = {
      "app.kubernetes.io/part-of" = "falco"
    }
  }

  data = {
    # Falco rules use YAML syntax with conditions written in
    # a filter expression language (similar to tcpdump/BPF filters).
    "custom-rules.yaml" = <<-YAML
      # =====================================================
      # Zero Trust Custom Falco Rules
      # =====================================================

      # RULE 1: Detect shell spawned inside a container
      # WHY: An attacker who compromises a web app (like Juice Shop)
      #      will try to spawn a shell for interactive access.
      #      Legitimate containers almost never need /bin/sh at runtime.
      - rule: ZT Shell Spawned in Container
        desc: >
          Detects when a shell process is started inside a container.
          This is a strong indicator of compromise — production containers
          should not need interactive shells.
        condition: >
          spawned_process
          and container
          and proc.name in (bash, sh, dash, ash, zsh, csh, ksh, fish)
          and not proc.pname in (containerd-shim, runc, cri-o, entrypoint.sh)
        output: >
          ALERT: Shell spawned in container
          (container=%container.name pod=%k8s.pod.name namespace=%k8s.ns.name
           user=%user.name shell=%proc.name parent=%proc.pname
           cmdline=%proc.cmdline)
        priority: WARNING
        tags: [zero-trust, mitre_execution, T1059]

      # RULE 2: Detect reading of sensitive files
      # WHY: Attackers look for credentials — /etc/shadow has password
      #      hashes, service account tokens give Kubernetes API access.
      - rule: ZT Sensitive File Read in Container
        desc: >
          Detects when a container reads sensitive files like /etc/shadow
          or Kubernetes service account tokens. Normal apps don't need these.
        condition: >
          open_read
          and container
          and (fd.name startswith /etc/shadow
               or fd.name startswith /var/run/secrets/kubernetes.io)
        output: >
          ALERT: Sensitive file read in container
          (file=%fd.name container=%container.name pod=%k8s.pod.name
           namespace=%k8s.ns.name user=%user.name process=%proc.name)
        priority: WARNING
        tags: [zero-trust, mitre_credential_access, T1552]

      # RULE 3: Detect unexpected outbound connections
      # WHY: If a container is compromised, the attacker will try to
      #      reach a C2 (command and control) server or exfiltrate data.
      #      Combined with our Cilium network policies, this provides
      #      defense-in-depth: Cilium blocks, Falco detects the attempt.
      - rule: ZT Unexpected Outbound Connection
        desc: >
          Detects outbound network connections from containers to
          non-standard ports. Helps catch C2 communication and data
          exfiltration attempts.
        condition: >
          outbound
          and container
          and not fd.sport in (53, 80, 443, 6443, 8080, 8443, 10250)
          and not k8s.ns.name in (kube-system, cilium, falco, monitoring)
        output: >
          ALERT: Unexpected outbound connection from container
          (container=%container.name pod=%k8s.pod.name namespace=%k8s.ns.name
           connection=%fd.name dest_port=%fd.sport)
        priority: NOTICE
        tags: [zero-trust, mitre_exfiltration, T1048]
    YAML
  }

  depends_on = [helm_release.falco]
}

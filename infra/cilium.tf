resource "helm_release" "cilium" {
	name = "cilium"
	namespace = "kube-system"
	repository = "https://helm.cilium.io/"
	chart = "cilium"
	version = "1.16.5"
	create_namespace = false

	set {
		name = "cni.exclusive"
		value = "false"
	}
	
	set {
		name = "hubble.relay.enabled"
		value = "true"
	}

	set {
		name = "hubble.ui.enabled"
		value = "true"
	}
	
	set {
		name = "operator.replicas"
		value = "1"
	}
}

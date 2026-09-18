resource "kubernetes_network_policy" "default_deny_juice_shop" {
	metadata {
		name = "default-deny-all"
		namespace = "juice-shop"
	}

	spec {
		pod_selector {}
		ingress {}
		egress {}
		policy_types = ["Ingress", "Egress"]
	}
}

resource "kubernetes_network_policy" "allow_juice_shop_ingress" {
	metadata {
		name = "allow-juice-shop-ingress"
		namespace = "juice-shop"
	}

	spec {
		pod_selector {
			match_labels = {
				app = "juice-shop"
			}
		}
		policy_types = ["Ingress"]
	}
}

resource "kubernetes_network_policy" "allow_juice_shop_dns" {
	metadata {
		name = "allow-juice-shop-dns"
		namespace = "juice-shop"
	}

	spec {
		pod_selector {
			match_labels = {
				app = "juice-shop"
			}
		}
		egress {
			ports {
				port = "53"
				protocol = "UDP"
			}
			ports {
				port = "53"
				protocol = "TCP"
			}
		}
		policy_types = ["Egress"]
	}
}

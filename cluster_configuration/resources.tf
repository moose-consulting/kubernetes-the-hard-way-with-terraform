provider "kubernetes" {
  load_config_file = "false"

  host = "https://${var.KUBERNETES_PUBLIC_ADDRESS}"

  cluster_ca_certificate = tls_self_signed_cert.ca.cert_pem
  client_key             = tls_private_key.admin.private_key_pem
  client_certificate     = tls_locally_signed_cert.admin.cert_pem
}

resource "kubernetes_cluster_role" "kube-apiserver-to-kubelet" {
  depends_on = [null_resource.start-kube-services]

  metadata {
    annotations = {
      "rbac.authorization.kubernetes.io/autoupdate" : "true"
    }
    labels = {
      "kubernetes.io/bootstrapping" : "rbac-defaults"
    }
    name = "system:kube-apiserver-to-kubelet"
  }

  rule {
    api_groups = [""]
    resources = [
      "nodes/proxy",
      "nodes/stats",
      "nodes/log",
      "nodes/spec",
      "nodes/metrics"
    ]
    verbs = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "system-kube-apiserver" {
  depends_on = [kubernetes_cluster_role.kube-apiserver-to-kubelet]

  metadata {
    name = "system:kube-apiserver"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:kube-apiserver-to-kubelet"
  }

  subject {
    kind      = "User"
    name      = "kubernetes"
    api_group = "rbac.authorization.k8s.io"
  }
}

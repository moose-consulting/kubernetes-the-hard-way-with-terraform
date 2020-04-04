resource "tls_private_key" "admin" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "admin" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.admin.private_key_pem
  subject {
    common_name         = "admin"
    organization        = "system:masters"
    organizational_unit = "Kubernetes The Hard Way"
    locality            = "Chicago"
    province            = "IL"
    country             = "US"
  }
}

resource "tls_locally_signed_cert" "admin" {
  cert_request_pem      = tls_cert_request.admin.cert_request_pem
  ca_key_algorithm      = "RSA"
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 8760
  allowed_uses          = ["cert_signing", "key_encipherment", "server_auth", "client_auth"]
}

module "admin-config" {
  source = "../kubeconfig"

  name            = "admin"
  username        = "admin"
  CLUSTER_ADDRESS = var.KUBERNETES_PUBLIC_ADDRESS
  ca              = null_resource.ca-cert.triggers.content
  cert            = [tls_locally_signed_cert.admin.cert_pem]
  key             = [tls_private_key.admin.private_key_pem]
}

resource "null_resource" "admin-config-deployment" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    key = module.admin-config.kubeconfig[0]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = module.admin-config.kubeconfig[0]
    destination = "/home/ubuntu/admin.kubeconfig"
  }
}

resource "local_file" "admin-config" {
  content  = module.admin-config.kubeconfig[0]
  filename = "${path.root}/admin.kubeconfig"
}

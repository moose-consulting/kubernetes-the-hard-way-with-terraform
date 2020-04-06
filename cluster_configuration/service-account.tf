resource "tls_private_key" "service-account" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "service-account" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.service-account.private_key_pem
  subject {
    common_name         = "service-account"
    organization        = "Kubernetes"
    organizational_unit = "Kubernetes The Hard Way"
    locality            = "Chicago"
    province            = "IL"
    country             = "US"
  }
}

resource "tls_locally_signed_cert" "service-account" {
  cert_request_pem      = tls_cert_request.service-account.cert_request_pem
  ca_key_algorithm      = "RSA"
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  allowed_uses          = ["cert_signing", "key_encipherment", "server_auth", "client_auth"]
  validity_period_hours = 8760
}

resource "null_resource" "service-account-key" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    key = sha256(tls_private_key.service-account.private_key_pem)
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = tls_private_key.service-account.private_key_pem
    destination = "/home/ubuntu/service-account-key.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/kubernetes/",
      "sudo cp /home/ubuntu/service-account-key.pem /var/lib/kubernetes/",
    ]
  }
}

resource "null_resource" "service-account-cert" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    key = sha256(tls_locally_signed_cert.service-account.cert_pem)
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = tls_locally_signed_cert.service-account.cert_pem
    destination = "/home/ubuntu/service-account.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/kubernetes/",
      "sudo cp /home/ubuntu/service-account.pem /var/lib/kubernetes/",
    ]
  }
}

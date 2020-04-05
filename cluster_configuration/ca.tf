resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.ca.private_key_pem

  validity_period_hours = 8760

  is_ca_certificate = true

  allowed_uses = ["cert_signing", "key_encipherment", "server_auth", "client_auth"]

  subject {
    common_name         = "Kubernetes"
    organization        = "Kubernetes"
    organizational_unit = "CA"
    locality            = "Chicago"
    province            = "IL"
    country             = "US"
  }
}

resource "local_file" "ca-cert" {
  sensitive_content = tls_self_signed_cert.ca.cert_pem
  filename          = "${path.root}/output/ca.pem"
}

resource "null_resource" "controller-ca-key" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    key = tls_private_key.ca.private_key_pem
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = tls_private_key.ca.private_key_pem
    destination = "/home/ubuntu/ca-key.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/kubernetes/",
      "sudo cp /home/ubuntu/ca-key.pem /var/lib/kubernetes/",
    ]
  }
}

resource "null_resource" "controller-ca-cert" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    key = tls_self_signed_cert.ca.cert_pem
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = tls_self_signed_cert.ca.cert_pem
    destination = "/home/ubuntu/ca.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/etcd",
      "sudo cp /home/ubuntu/ca.pem /etc/etcd/",
      "sudo mkdir -p /var/lib/kubernetes/",
      "sudo cp /home/ubuntu/ca.pem /var/lib/kubernetes/",
    ]
  }
}

resource "null_resource" "worker-ca-cert" {
  count = length(var.cluster_ips.workers.public)

  triggers = {
    key = tls_self_signed_cert.ca.cert_pem
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.workers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = tls_self_signed_cert.ca.cert_pem
    destination = "/home/ubuntu/ca.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/kubernetes/",
      "sudo cp /home/ubuntu/ca.pem /var/lib/kubernetes/",
    ]
  }
}

resource "tls_private_key" "worker" {
  count = length(var.cluster_ips.workers.private)

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "worker" {
  count = length(var.cluster_ips.workers.private)

  dns_names       = ["worker-${count.index}", var.cluster_ips.workers.private[count.index], var.cluster_ips.workers.public[count.index]]
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.worker[count.index].private_key_pem
  subject {
    common_name         = "system:nodes:worker-${count.index}"
    organization        = "system:nodes"
    organizational_unit = "Kubernetes The Hard Way"
    locality            = "Chicago"
    province            = "IL"
    country             = "US"
  }
}

resource "tls_locally_signed_cert" "worker" {
  count = length(var.cluster_ips.workers.private)

  cert_request_pem      = tls_cert_request.worker[count.index].cert_request_pem
  ca_key_algorithm      = "RSA"
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  allowed_uses          = ["cert_signing", "key_encipherment", "server_auth", "client_auth"]
  validity_period_hours = 8760
}

resource "null_resource" "worker-key" {
  count = length(var.cluster_ips.workers.public)

  triggers = {
    key = tls_private_key.worker[count.index].private_key_pem
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.workers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = tls_private_key.worker[count.index].private_key_pem
    destination = "/home/ubuntu/worker-${count.index}-key.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/kubelet/",
      "sudo cp /home/ubuntu/worker-${count.index}-key.pem /var/lib/kubelet/"
    ]
  }
}

resource "null_resource" "worker-cert" {
  count = length(var.cluster_ips.workers.public)

  triggers = {
    key = tls_locally_signed_cert.worker[count.index].cert_pem
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.workers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = tls_locally_signed_cert.worker[count.index].cert_pem
    destination = "/home/ubuntu/worker-${count.index}.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/kubelet/",
      "sudo cp /home/ubuntu/worker-${count.index}.pem /var/lib/kubelet/",
    ]
  }
}

resource "tls_private_key" "kubernetes" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kubernetes" {
  ip_addresses = concat(var.cluster_ips.controllers.private, [
    var.KUBERNETES_PUBLIC_ADDRESS,
    "10.32.0.1",
    "127.0.0.1"
  ])

  dns_names = [
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.svc.cluster.local"
  ]

  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.kubernetes.private_key_pem
  subject {
    common_name         = "kubernetes"
    organization        = "Kubernetes"
    organizational_unit = "Kubernetes The Hard Way"
    locality            = "Chicago"
    province            = "IL"
    country             = "US"
  }
}

resource "tls_locally_signed_cert" "kubernetes" {
  cert_request_pem      = tls_cert_request.kubernetes.cert_request_pem
  ca_key_algorithm      = "RSA"
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  allowed_uses          = ["cert_signing", "key_encipherment", "server_auth", "client_auth"]
  validity_period_hours = 8760
}

resource "null_resource" "kubernetes-key" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    key = sha256(tls_private_key.kubernetes.private_key_pem)
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = tls_private_key.kubernetes.private_key_pem
    destination = "/home/ubuntu/kubernetes-key.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/etcd",
      "sudo cp /home/ubuntu/kubernetes-key.pem /etc/etcd/",
      "sudo mkdir -p /var/lib/kubernetes/",
      "sudo cp /home/ubuntu/kubernetes-key.pem /var/lib/kubernetes/",
    ]
  }
}

resource "null_resource" "kubernetes-cert" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    key = sha256(tls_locally_signed_cert.kubernetes.cert_pem)
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = tls_locally_signed_cert.kubernetes.cert_pem
    destination = "/home/ubuntu/kubernetes.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/etcd",
      "sudo cp /home/ubuntu/kubernetes.pem /etc/etcd/",
      "sudo mkdir -p /var/lib/kubernetes/",
      "sudo cp /home/ubuntu/kubernetes.pem /var/lib/kubernetes/",
    ]
  }
}

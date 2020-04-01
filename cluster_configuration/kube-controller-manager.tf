resource "tls_private_key" "kube-controller-manager" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kube-controller-manager" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.kube-controller-manager.private_key_pem
  subject {
    common_name         = "system:kube-controller-manager"
    organization        = "system:kube-controller-manager"
    organizational_unit = "Kubernetes The Hard Way"
    locality            = "Chicago"
    province            = "IL"
    country             = "US"
  }
}

resource "tls_locally_signed_cert" "kube-controller-manager" {
  cert_request_pem      = tls_cert_request.kube-controller-manager.cert_request_pem
  ca_key_algorithm      = "RSA"
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  allowed_uses          = ["cert_signing", "key_encipherment", "server_auth", "client_auth"]
  validity_period_hours = 8760
}

module "kube-controller-manager-config" {
  source = "../kubeconfig"

  name            = "kube-controller-manager"
  username        = "system:kube-controller-manager"
  CLUSTER_ADDRESS = "127.0.0.1"
  ca              = null_resource.ca-cert.triggers.content
  cert            = [tls_locally_signed_cert.kube-controller-manager.cert_pem]
  key             = [tls_private_key.kube-controller-manager.private_key_pem]
}

resource "null_resource" "kube-controller-manager-config-deployment" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    key = module.kube-controller-manager-config.kubeconfig[0]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = module.kube-controller-manager-config.kubeconfig[0]
    destination = "/home/ubuntu/kube-controller-manager.kubeconfig"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/kubernetes",
      "sudo cp /home/ubuntu/kube-controller-manager.kubeconfig /var/lib/kubernetes/kube-controller-manager.kubeconfig"
    ]
  }
}

data "template_file" "kube-controller-manager-systemd" {
  template = "${file("${path.root}/templates/kube-controller-manager.service")}"
  vars = {
  }
}

resource "null_resource" "install-kube-controller-manager" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    key = var.cluster_ips.controllers.public[count.index]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "remote-exec" {
    inline = [
      "wget https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-controller-manager",
      "chmod +x kube-controller-manager",
      "sudo mv kube-controller-manager /usr/local/bin/",
    ]
  }
}

resource "null_resource" "configure-kube-controller-manager" {
  count = length(var.cluster_ips.controllers.public)

  depends_on = [
    null_resource.controller-ca-cert,
    null_resource.controller-ca-key,
    null_resource.service-account-key,
    null_resource.kube-controller-manager-config-deployment
  ]

  triggers = {
    ca-cert                        = tls_self_signed_cert.ca.cert_pem
    ca-key                         = tls_private_key.ca.private_key_pem
    systemd                        = data.template_file.kube-controller-manager-systemd.rendered
    service-account-key            = tls_private_key.service-account.private_key_pem
    kube-controller-manager-config = module.kube-controller-manager-config.kubeconfig[0]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = data.template_file.kube-controller-manager-systemd.rendered
    destination = "/home/ubuntu/kube-controller-manager.service"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cp /home/ubuntu/kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service",
    ]
  }
}

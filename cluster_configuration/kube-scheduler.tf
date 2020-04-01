resource "tls_private_key" "kube-scheduler" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kube-scheduler" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.kube-scheduler.private_key_pem
  subject {
    common_name         = "system:kube-scheduler"
    organization        = "system:kube-scheduler"
    organizational_unit = "Kubernetes The Hard Way"
    locality            = "Chicago"
    province            = "IL"
    country             = "US"
  }
}

resource "tls_locally_signed_cert" "kube-scheduler" {
  cert_request_pem      = tls_cert_request.kube-scheduler.cert_request_pem
  ca_key_algorithm      = "RSA"
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  allowed_uses          = ["cert_signing", "key_encipherment", "server_auth", "client_auth"]
  validity_period_hours = 8760
}

module "kube-scheduler-config" {
  source = "../kubeconfig"

  name            = "kube-scheduler"
  username        = "system:kube-scheduler"
  CLUSTER_ADDRESS = "127.0.0.1"
  ca              = null_resource.ca-cert.triggers.content
  cert            = [tls_locally_signed_cert.kube-scheduler.cert_pem]
  key             = [tls_private_key.kube-scheduler.private_key_pem]
}

resource "null_resource" "kube-scheduler-config-deployment" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    key = module.kube-scheduler-config.kubeconfig[0]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = module.kube-scheduler-config.kubeconfig[0]
    destination = "/home/ubuntu/kube-scheduler.kubeconfig"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/kubernetes",
      "sudo cp /home/ubuntu/kube-scheduler.kubeconfig /var/lib/kubernetes/kube-scheduler.kubeconfig"
    ]
  }
}

data "template_file" "kube-scheduler-yaml" {
  template = "${file("${path.root}/templates/kube-scheduler.yaml")}"
  vars = {
  }
}


data "template_file" "kube-scheduler-systemd" {
  template = "${file("${path.root}/templates/kube-scheduler.service")}"
  vars = {
  }
}

resource "null_resource" "install-kube-scheduler" {
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
      "wget https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-scheduler",
      "chmod +x kube-scheduler",
      "sudo mv kube-scheduler /usr/local/bin/",
    ]
  }
}

resource "null_resource" "configure-kube-scheduler" {
  count = length(var.cluster_ips.controllers.public)

  depends_on = [
    null_resource.kube-scheduler-config-deployment
  ]

  triggers = {
    systemd               = data.template_file.kube-scheduler-systemd.rendered
    yaml                  = data.template_file.kube-scheduler-yaml.rendered
    kube-scheduler-config = module.kube-scheduler-config.kubeconfig[0]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = data.template_file.kube-scheduler-systemd.rendered
    destination = "/home/ubuntu/kube-scheduler.service"
  }

  provisioner "file" {
    content     = data.template_file.kube-scheduler-yaml.rendered
    destination = "/home/ubuntu/kube-scheduler.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/kubernetes/config",
      "sudo cp /home/ubuntu/kube-scheduler.service /etc/systemd/system/kube-scheduler.service",
      "sudo cp /home/ubuntu/kube-scheduler.yaml /etc/kubernetes/config/kube-scheduler.yaml",
    ]
  }
}

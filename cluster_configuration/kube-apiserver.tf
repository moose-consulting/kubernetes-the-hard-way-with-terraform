data "template_file" "kube-apiserver-systemd" {
  count = length(var.cluster_ips.controllers.public)

  template = "${file("${path.root}/templates/kube-apiserver.service")}"
  vars = {
    INTERNAL_IP   = var.cluster_ips.controllers.private[count.index]
    ETCD_SERVERS  = join(",", formatlist("https://%s:2379", var.cluster_ips.controllers.private))
    N_CONTROLLERS = length(var.cluster_ips.controllers.public)
  }
}

resource "null_resource" "install-kube-apiserver" {
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
      "wget https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-apiserver",
      "chmod +x kube-apiserver",
      "sudo mv kube-apiserver /usr/local/bin/",
    ]
  }
}

resource "null_resource" "configure-kube-apiserver" {
  count = length(var.cluster_ips.controllers.public)

  depends_on = [
    null_resource.controller-ca-cert,
    null_resource.kubernetes-cert,
    null_resource.kubernetes-key,
    null_resource.encryption-key-deployment,
    null_resource.service-account-cert
  ]

  triggers = {
    ca-cert              = tls_self_signed_cert.ca.cert_pem
    kubernetes-cert      = sha256(tls_locally_signed_cert.kubernetes.cert_pem)
    kubernetes-key       = sha256(tls_private_key.kubernetes.private_key_pem)
    systemd              = data.template_file.kube-apiserver-systemd[count.index].rendered
    encryption-config    = sha256(data.template_file.encryption-config.rendered)
    service-account-cert = sha256(tls_locally_signed_cert.service-account.cert_pem)
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = data.template_file.kube-apiserver-systemd[count.index].rendered
    destination = "/home/ubuntu/kube-apiserver.service"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cp /home/ubuntu/kube-apiserver.service /etc/systemd/system/kube-apiserver.service",
    ]
  }
}

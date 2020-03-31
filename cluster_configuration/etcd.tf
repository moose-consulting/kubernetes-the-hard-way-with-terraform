resource "null_resource" "install-etcd" {
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
      "wget https://github.com/etcd-io/etcd/releases/download/v3.4.0/etcd-v3.4.0-linux-amd64.tar.gz",
      "tar -xvf etcd-v3.4.0-linux-amd64.tar.gz",
      "sudo mv etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/",
      "sudo mkdir -p /etc/etcd /var/lib/etcd"
    ]
  }
}

resource "null_resource" "controller-hostname" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    hostname = "controller-${count.index}"
  }
}

data "template_file" "etcd-systemd" {
  count = length(var.cluster_ips.controllers.public)

  template = "${file("${path.root}/templates/etcd.systemd")}"
  vars = {
    ETCD_NAME       = "controller-${count.index}"
    INTERNAL_IP     = var.cluster_ips.controllers.private[count.index]
    INITIAL_CLUSTER = join(",", formatlist("%s=https://%s:2380", null_resource.controller-hostname.*.triggers.hostname, var.cluster_ips.controllers.private))
  }
}

resource "null_resource" "start-etcd" {
  count = length(var.cluster_ips.controllers.public)

  depends_on = [
    null_resource.controller-ca-cert,
    null_resource.kubernetes-cert,
    null_resource.kubernetes-key,
    null_resource.install-etcd
  ]

  triggers = {
    ca-cert         = tls_self_signed_cert.ca.cert_pem
    kubernetes-cert = tls_locally_signed_cert.kubernetes.cert_pem
    kubernetes-key  = tls_private_key.kubernetes.private_key_pem
    systemd         = data.template_file.etcd-systemd[count.index].rendered
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = data.template_file.etcd-systemd[count.index].rendered
    destination = "/home/ubuntu/etcd.systemd"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cp /home/ubuntu/etcd.systemd /etc/systemd/system/etcd.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl stop etcd",
      "sudo systemctl enable etcd",
      "sudo systemctl start etcd"
    ]
  }
}

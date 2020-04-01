provider "tls" {}

resource "null_resource" "install-kubectl" {
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
      "wget https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl",
      "chmod +x kubectl",
      "sudo mv kubectl /usr/local/bin/",
    ]
  }
}

resource "null_resource" "start-kube-services" {
  count = length(var.cluster_ips.controllers.public)

  depends_on = [
    null_resource.install-kube-apiserver,
    null_resource.configure-kube-apiserver,
    null_resource.install-kube-controller-manager,
    null_resource.configure-kube-controller-manager,
    null_resource.install-kube-scheduler,
    null_resource.configure-kube-scheduler
  ]

  triggers = {
    kube-apiserver          = null_resource.configure-kube-apiserver[count.index].id
    kube-controller-manager = null_resource.configure-kube-controller-manager[count.index].id
    kube-scheduler          = null_resource.configure-kube-scheduler[count.index].id
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl daemon-reload",
      "sudo systemctl stop kube-apiserver kube-controller-manager kube-scheduler",
      "sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler",
      "sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler",
      "sleep 10"
    ]
  }
}

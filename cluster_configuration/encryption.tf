provider "random" {}

resource "random_password" "encryption_key" {
  length = 32
}

data "template_file" "encryption-config" {
  template = "${file("${path.root}/templates/encryption-config.yaml")}"
  vars = {
    ENCRYPTION_KEY = random_password.encryption_key.result
  }
}

resource "null_resource" "encryption-key-deployment" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    key = data.template_file.encryption-config.rendered
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = data.template_file.encryption-config.rendered
    destination = "/home/ubuntu/encryption-config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/kubernetes",
      "sudo cp /home/ubuntu/encryption-config.yaml /var/lib/kubernetes/encryption-config.yaml"
    ]
  }
}

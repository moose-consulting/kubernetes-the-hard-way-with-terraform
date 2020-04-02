data "template_file" "containerd-toml" {
  template = "${file("${path.root}/templates/containerd.toml")}"
  vars = {
  }
}

data "template_file" "containerd-service" {
  template = "${file("${path.root}/templates/containerd.service")}"
  vars = {
  }
}

resource "null_resource" "containerd" {
  count = length(var.cluster_ips.workers.public)

  triggers = {
    containerd-toml    = data.template_file.containerd-toml.rendered
    containerd-service = data.template_file.containerd-service.rendered
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.workers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = data.template_file.containerd-toml.rendered
    destination = "/home/ubuntu/containerd.toml"
  }

  provisioner "file" {
    content     = data.template_file.containerd-service.rendered
    destination = "/home/ubuntu/containerd.service"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/containerd",
      "sudo cp /home/ubuntu/containerd.service /etc/systemd/system/containerd.service",
      "sudo cp /home/ubuntu/containerd.toml /etc/containerd/config.toml",
    ]
  }
}

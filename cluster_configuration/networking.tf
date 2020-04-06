data "template_file" "bridge" {
  count = length(var.cluster_ips.workers.public)

  template = "${file("${path.root}/templates/10-bridge.conf")}"
  vars = {
    POD_CIDR = "10.200.${count.index}.0/24"
  }
}

data "template_file" "loopback" {
  template = "${file("${path.root}/templates/99-loopback.conf")}"
  vars = {
  }
}

resource "null_resource" "networking" {
  count = length(var.cluster_ips.workers.public)

  triggers = {
    bridge   = data.template_file.bridge[count.index].rendered
    loopback = data.template_file.loopback.rendered
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.workers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "file" {
    content     = data.template_file.bridge[count.index].rendered
    destination = "/home/ubuntu/10-bridge.conf"
  }

  provisioner "file" {
    content     = data.template_file.loopback.rendered
    destination = "/home/ubuntu/99-loopback.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/cni/net.d",
      "sudo cp /home/ubuntu/10-bridge.conf /etc/cni/net.d/10-bridge.conf",
      "sudo cp /home/ubuntu/99-loopback.conf /etc/cni/net.d/99-loopback.conf",
    ]
  }
}

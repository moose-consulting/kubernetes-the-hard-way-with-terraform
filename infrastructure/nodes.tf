resource "tls_private_key" "access" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "cluster" {
  key_name   = "kubernetes-the-hard-way-${terraform.workspace}"
  public_key = tls_private_key.access.public_key_openssh
}

resource "local_file" "ssh" {
  content         = tls_private_key.access.private_key_pem
  filename        = "${path.root}/.ssh/${terraform.workspace}.pem"
  file_permission = "0400"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  filter {
    name   = "description"
    values = ["*2020-03-23"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


resource "aws_instance" "worker" {
  count      = var.n_workers
  depends_on = [aws_internet_gateway.gw]

  ami                         = data.aws_ami.ubuntu.id
  availability_zone           = var.zone
  vpc_security_group_ids      = [aws_security_group.cluster.id]
  instance_type               = var.worker_instance_type
  associate_public_ip_address = true
  private_ip                  = "10.240.0.2${count.index}"
  key_name                    = aws_key_pair.cluster.key_name
  subnet_id                   = aws_subnet.cluster.id
  tags = {
    Name        = "kubernetes-the-hard-way-${terraform.workspace}-worker-${count.index}"
    ManagedBy   = "Terraform"
    Type        = "Worker"
    Environment = terraform.workspace
  }

  root_block_device {
    volume_size = 200
  }

  user_data = "#!/bin/bash\nexport POD_CIDR=10.200.${count.index}.0/24"
}

resource "null_resource" "bootstrap_worker" {
  count = var.n_workers

  depends_on = [aws_instance.worker]

  triggers = {
    id = aws_instance.worker[count.index].id
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.worker[count.index].public_ip
    private_key = tls_private_key.access.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname worker-${count.index}",
      "sudo apt-get update",
      "sudo apt-get -y install socat conntrack ipset",
      "sudo swapoff -a",
      "wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.18.0/crictl-v1.18.0-linux-amd64.tar.gz",
      "wget https://github.com/opencontainers/runc/releases/download/v1.0.0-rc10/runc.amd64",
      "wget https://github.com/containernetworking/plugins/releases/download/v0.8.5/cni-plugins-linux-amd64-v0.8.5.tgz",
      "wget https://github.com/containerd/containerd/releases/download/v1.2.13/containerd-1.2.13.linux-amd64.tar.gz",
      "wget https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl",
      "wget https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kube-proxy",
      "wget https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubelet",
      "sudo mkdir -p /etc/cni/net.d /opt/cni/bin /var/lib/kubelet /var/lib/kube-proxy /var/lib/kubernetes /var/run/kubernetes",
      "mkdir containerd",
      "tar -xvf crictl-v1.18.0-linux-amd64.tar.gz",
      "tar -xvf containerd-1.2.13.linux-amd64.tar.gz -C containerd",
      "sudo tar -xvf cni-plugins-linux-amd64-v0.8.5.tgz -C /opt/cni/bin/",
      "sudo mv runc.amd64 runc",
      "chmod +x crictl kubectl kube-proxy kubelet runc",
      "sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/",
      "sudo mv containerd/bin/* /bin/",
      "sudo modprobe br_netfilter"
    ]
  }
}

resource "aws_instance" "controller" {
  count      = var.n_controllers
  depends_on = [aws_internet_gateway.gw]

  ami                         = data.aws_ami.ubuntu.id
  availability_zone           = var.zone
  vpc_security_group_ids      = [aws_security_group.cluster.id]
  instance_type               = var.controller_instance_type
  associate_public_ip_address = true
  private_ip                  = "10.240.0.1${count.index}"
  key_name                    = aws_key_pair.cluster.key_name
  subnet_id                   = aws_subnet.cluster.id

  tags = {
    Name        = "kubernetes-the-hard-way-${terraform.workspace}-controller-${count.index}"
    ManagedBy   = "Terraform"
    Type        = "Controller"
    Environment = terraform.workspace
  }

  root_block_device {
    volume_size = 200
  }

}

resource "null_resource" "set_controller_hostname" {
  count = var.n_controllers

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.controller[count.index].public_ip
    private_key = tls_private_key.access.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname controller-${count.index}",
    ]
  }
}

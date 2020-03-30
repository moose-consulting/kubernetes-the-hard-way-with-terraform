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
  filename        = "${path.root}/.ssh/key.pem"
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

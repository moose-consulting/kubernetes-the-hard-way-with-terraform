resource "aws_instance" "controller" {
  count = var.n_controllers

  ami                         = data.aws_ami.ubuntu.id
  availability_zone           = var.zone
  vpc_security_group_ids      = [var.security_group_id]
  instance_type               = var.controller_instance_type
  associate_public_ip_address = true
  private_ip                  = "10.240.0.1${count.index}"
  key_name                    = aws_key_pair.cluster.key_name
  subnet_id                   = var.subnet_id

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

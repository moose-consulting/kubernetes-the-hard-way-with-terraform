resource "aws_instance" "worker" {
  count = var.n_workers

  ami                         = data.aws_ami.ubuntu.id
  availability_zone           = var.zone
  vpc_security_group_ids      = [var.security_group_id]
  instance_type               = var.worker_instance_type
  associate_public_ip_address = true
  private_ip                  = "10.240.0.2${count.index}"
  key_name                    = aws_key_pair.cluster.key_name
  subnet_id                   = var.subnet_id
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

resource "aws_security_group" "cluster" {
  name        = "kubernetes-the-hard-way-${terraform.workspace}"
  description = "Cluster Node Security Group"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "kubernetes-the-hard-way-${terraform.workspace}"
    ManagedBy   = "Terraform"
    Environment = terraform.workspace
  }
}

resource "aws_security_group_rule" "internal-tcp" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "tcp"
  cidr_blocks       = ["10.240.0.0/24", "10.200.0.0/16"]
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "internal-udp" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "udp"
  cidr_blocks       = ["10.240.0.0/24", "10.200.0.0/16"]
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "internal-icmp" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["10.240.0.0/24", "10.200.0.0/16"]
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "external-icmp" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "external-ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "external-api" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

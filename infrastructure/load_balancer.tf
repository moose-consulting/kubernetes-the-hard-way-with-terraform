resource "aws_lb" "lb" {
  name               = "kubernetes-the-hard-way-${terraform.workspace}"
  internal           = false
  load_balancer_type = "network"
  ip_address_type    = "ipv4"

  tags = {
    Name        = "kubernetes-the-hard-way-${terraform.workspace}"
    ManagedBy   = "Terraform"
    Environment = terraform.workspace
  }

  subnet_mapping {
    subnet_id     = aws_subnet.cluster.id
    allocation_id = aws_eip.lb.id
  }
}

resource "aws_lb_target_group" "cluster" {
  name     = "kubernetes-the-hard-way-${terraform.workspace}"
  port     = 6443
  protocol = "TCP"
  vpc_id   = aws_vpc.cluster.id

  tags = {
    Name        = "kubernetes-the-hard-way-${terraform.workspace}"
    ManagedBy   = "Terraform"
    Environment = terraform.workspace
  }

  health_check {
    protocol            = "HTTPS"
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cluster.arn
  }
}

resource "aws_eip" "lb" {
  depends_on = [aws_internet_gateway.gw]
  tags = {
    Name        = "kubernetes-the-hard-way-${terraform.workspace}"
    ManagedBy   = "Terraform"
    Environment = terraform.workspace
  }
}

resource "aws_lb_target_group_attachment" "controller" {
  count = length(aws_instance.controller.*.id)

  target_group_arn = aws_lb_target_group.cluster.arn
  target_id        = aws_instance.controller[count.index].id
  port             = 6443
}



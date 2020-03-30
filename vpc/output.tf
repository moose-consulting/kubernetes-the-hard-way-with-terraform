output "vpc_id" {
  value = aws_vpc.cluster.id
}

output "subnet_id" {
  value = aws_subnet.cluster.id
}

output "stub_id" {
  value = aws_subnet.stub.id
}

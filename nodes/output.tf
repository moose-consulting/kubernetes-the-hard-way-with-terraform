output "cluster_ips" {
  value = {
    "workers" = {
      "public"  = aws_instance.worker.*.public_ip,
      "private" = aws_instance.worker.*.private_ip
    },
    "controllers" = {
      "public"  = aws_instance.controller.*.public_ip,
      "private" = aws_instance.controller.*.private_ip
    }
  }
}

output "ssh_key" {
  sensitive = true
  value     = tls_private_key.access.private_key_pem
}

output "controller_ids" {
  value = aws_instance.controller.*.id
}

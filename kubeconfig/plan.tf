locals {
  multiple = (length(var.cert) > 1) || (var.name == "worker")
}

resource "local_file" "cert" {
  count = length(var.cert)

  sensitive_content = var.cert[count.index]
  filename          = "${path.root}/output/${var.name}${local.multiple ? join("", ["-", tostring(count.index)]) : ""}.pem"
}

resource "local_file" "key" {
  count             = length(var.cert)
  sensitive_content = var.key[count.index]
  filename          = "${path.root}/output/${var.name}${local.multiple ? join("", ["-", tostring(count.index)]) : ""}-key.pem"
}

resource "null_resource" "config" {
  count      = length(var.cert)
  depends_on = [local_file.cert, local_file.key]

  triggers = {
    ca-cert = var.ca
    cert    = var.cert[count.index]
    key     = var.key[count.index]
  }

  provisioner "local-exec" {
    command = "kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=${path.root}/output/ca.pem --embed-certs=true --server=https://${var.CLUSTER_ADDRESS}:6443 --kubeconfig=${path.root}/output/${var.name}${local.multiple ? join("", ["-", tostring(count.index)]) : ""}.kubeconfig"
  }

  provisioner "local-exec" {
    command = "kubectl config set-credentials ${var.username}${local.multiple ? join("", ["-", tostring(count.index)]) : ""} --client-certificate=${path.root}/output/${var.name}${local.multiple ? join("", ["-", tostring(count.index)]) : ""}.pem --client-key=${path.root}/output/${var.name}${local.multiple ? join("", ["-", tostring(count.index)]) : ""}-key.pem --embed-certs=true --kubeconfig=${path.root}/output/${var.name}${local.multiple ? join("", ["-", tostring(count.index)]) : ""}.kubeconfig"
  }

  provisioner "local-exec" {
    command = "kubectl config set-context default --cluster=kubernetes-the-hard-way --user=${var.username}${local.multiple ? join("", ["-", tostring(count.index)]) : ""} --kubeconfig=${path.root}/output/${var.name}${local.multiple ? join("", ["-", tostring(count.index)]) : ""}.kubeconfig"
  }

  provisioner "local-exec" {
    command = "kubectl config use-context default --kubeconfig=${path.root}/output/${var.name}${local.multiple ? join("", ["-", tostring(count.index)]) : ""}.kubeconfig"
  }
}

resource "null_resource" "config-output" {
  depends_on = [null_resource.config]
  count      = length(var.cert)
  triggers = {
    // Hack to defer file reading until after local_exec runs.
    content = file(replace("${path.root}/output/${var.name}${local.multiple ? join("", ["-", tostring(count.index)]) : ""}.kubeconfig*${null_resource.config[count.index].id}", "/[*].*/", ""))
  }
}

output "kubeconfig" {
  sensitive = true
  value     = null_resource.config-output.*.triggers.content
}

locals {
  multiple = (length(var.cert) > 1) || (var.username == "system:node:worker")
}

data "template_file" "kubeconfig" {
  count = length(var.cert)

  template = "${file("${path.root}/templates/kubeconfig")}"
  vars = {
    USERNAME = local.multiple ? join("", [var.username, "-", tostring(count.index)]) : var.username
    CLUSTER_ADDRESS = var.CLUSTER_ADDRESS
    CA_CERT = base64encode(var.ca)
    CLIENT_CERT = base64encode(var.cert[count.index])
    CLIENT_KEY = base64encode(var.key[count.index])
  }
}

output "kubeconfig" {
  sensitive = true
  value     = data.template_file.kubeconfig.*.rendered
}

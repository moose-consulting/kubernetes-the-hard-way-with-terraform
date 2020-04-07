provider "tls" {}

resource "null_resource" "install-kubectl" {
  count = length(var.cluster_ips.controllers.public)

  triggers = {
    key = var.cluster_ips.controllers.public[count.index]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "remote-exec" {
    inline = [
      "wget https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl",
      "chmod +x kubectl",
      "sudo mv kubectl /usr/local/bin/",
    ]
  }
}

resource "null_resource" "start-kube-services" {
  count = length(var.cluster_ips.controllers.public)

  depends_on = [
    null_resource.install-kube-apiserver,
    null_resource.configure-kube-apiserver,
    null_resource.install-kube-controller-manager,
    null_resource.configure-kube-controller-manager,
    null_resource.install-kube-scheduler,
    null_resource.configure-kube-scheduler
  ]

  triggers = {
    kube-apiserver          = null_resource.configure-kube-apiserver[count.index].id
    kube-controller-manager = null_resource.configure-kube-controller-manager[count.index].id
    kube-scheduler          = null_resource.configure-kube-scheduler[count.index].id
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.controllers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl daemon-reload",
      "sudo systemctl stop kube-apiserver kube-controller-manager kube-scheduler",
      "sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler",
      "sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler",
      "sleep 10"
    ]
  }
}

resource "null_resource" "start-worker-services" {
  count = length(var.cluster_ips.workers.public)

  depends_on = [
    null_resource.networking,
    null_resource.containerd,
    null_resource.kube-proxy-config,
    null_resource.kubelet-config,
    null_resource.worker-config-deployment,
  ]

  triggers = {
    networking     = null_resource.networking[count.index].id,
    containerd     = null_resource.containerd[count.index].id,
    kube-proxy     = null_resource.kube-proxy-config[count.index].id,
    kubelet        = null_resource.kubelet-config[count.index].id,
    kubelet-config = null_resource.worker-config-deployment[count.index].id
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.cluster_ips.workers.public[count.index]
    private_key = var.ssh_key
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl daemon-reload",
      "sudo systemctl stop containerd kubelet kube-proxy",
      "sudo systemctl enable containerd kubelet kube-proxy",
      "sudo systemctl start containerd kubelet kube-proxy",
      "sleep 10"
    ]
  }
}

resource "null_resource" "wait-kube-apiserver" {
  depends_on = [
    null_resource.start-kube-services,
    local_file.ca-cert,
    null_resource.start-worker-services
  ]

  provisioner "local-exec" {
    working_dir = path.root
    command     = "until $(curl --cacert output/${terraform.workspace}/ca.pem --output /dev/null --silent --fail --max-time 5 https://${var.KUBERNETES_PUBLIC_ADDRESS}:6443/healthz); do printf '.'; sleep 5; done"
  }
}

resource "null_resource" "kubelet_cluster_role" {
  depends_on = [
    null_resource.wait-kube-apiserver,
  ]

  provisioner "local-exec" {
    working_dir = path.root
    command     = "kubectl --kubeconfig ${terraform.workspace}.kubeconfig apply -f templates/kube-apiserver-to-kubelet.cluster_role"
  }
}

resource "null_resource" "kubelet_cluster_role_binding" {
  depends_on = [
    null_resource.kubelet_cluster_role
  ]

  provisioner "local-exec" {
    working_dir = path.root
    command     = "kubectl --kubeconfig ${terraform.workspace}.kubeconfig apply -f templates/kubernetes.cluster_role_binding"
  }
}

resource "null_resource" "coredns" {
  depends_on = [
    null_resource.kubelet_cluster_role_binding
  ]

  provisioner "local-exec" {
    working_dir = path.root
    command     = "kubectl --kubeconfig ${terraform.workspace}.kubeconfig apply -f templates/coredns.yaml"
  }
}

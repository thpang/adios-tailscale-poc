locals {
  kubeconfig = templatefile("${path.module}/templates/kubeconfig.tmpl", {
    prefix       = var.prefix
    cluster_name = var.cluster_name
    endpoint     = var.endpoint
    ca_crt       = var.ca_crt
    region       = var.region
  })
}

resource "local_file" "kubeconfig" {
  content              = local.kubeconfig
  filename             = var.path
  file_permission      = "0644"
  directory_permission = "0755"

}

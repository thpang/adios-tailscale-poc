output "kube_config" {
  description = "Kubernetes cluster authentication information for kubectl."
  value       = local_file.kubeconfig.content
}

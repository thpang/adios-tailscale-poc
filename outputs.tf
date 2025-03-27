# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "cluster_names" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.*.cluster_name
}

output "kubeconfigs" {
  description = "Kubeconfig files for the EKS cluster"
  value       = module.kubeconfig.*.kube_config
}

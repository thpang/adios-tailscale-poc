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

output "irsa-ebs-csi" {
  description = "IAM role for ebs-csi-controller Service Account"
  value       = module.irsa-ebs-csi.*.iam_assumable_role_with_oidc
}

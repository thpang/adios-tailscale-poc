# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "ubuntu_ami" {
  description = "Ubuntu AMI"
  value       = data.aws_ami.ubuntu
}

output "cluster_names" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.*.cluster_name
}

output "kubeconfigs" {
  description = "Kubeconfig files for the EKS cluster"
  value       = module.kubeconfig.*.kube_config
}

# Copyright © 2021-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "prefix" {
  description = "A prefix used for all Google Cloud resources created by this script"
  type        = string
}

variable "region" {
  description = "AWS Region this cluster was provisioned in"
  type        = string
  default     = null
}

variable "path" {
  description = "Path to output the kubeconfig file"
  type        = string
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
}

variable "endpoint" {
  description = "Kubernetes cluster endpoint"
  type        = string
}

variable "ca_crt" {
  description = "Kubernetes CA certificate"
  type        = string
}

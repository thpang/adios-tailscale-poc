# Copyright © 2021-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "cluster_name" {
  description = "Name of EKS cluster"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags used for aws ebs csi objects"
  type        = map(any)
  default     = null
}

variable "oidc_url" {
  description = "OIDC URL of EKS cluster"
  type        = string
  default     = ""
}

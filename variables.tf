# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Global
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "prefix" {
  description = "Prefix to be added to resources"
  type        = string
  default     = "education"

}

# VPC
variable "vpc_count" {
  description = "Number of VPCs to create"
  type        = number
  default     = 2

}

variable "vpc_zone_count" {
  description = "Number of zones to create in each VPC"
  type        = number
  default     = 2

}

variable "vpc_cidr_mask" {
  description = "CIDR mask for VPC"
  type        = number
  default     = 21

}

# EKS
variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.32"

}

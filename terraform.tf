# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {

  # cloud {
  #   workspaces {
  #     name = "learn-terraform-eks"
  #   }
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2"
    }
  }

  required_version = "~> 1.3"
}


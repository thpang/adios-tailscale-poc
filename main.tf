# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = var.region
}

# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  tags = {
    smart_parking_disabled = "True"
  }
}

module "vpc" {
  count   = var.vpc_count
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = format("%s-vpc-%02d", var.prefix, count.index)
  cidr = format("10.%d.0.0/21", count.index)
  azs  = slice(data.aws_availability_zones.available.names, 0, var.vpc_zone_count)

  private_subnets = flatten([for i in range(var.vpc_zone_count) : cidrsubnet(format("10.%d.0.0/21", count.index), 3, i + 1)])
  public_subnets  = flatten([for i in range(var.vpc_zone_count) : cidrsubnet(format("10.%d.0.0/21", count.index), 3, i + 3)])
  intra_subnets   = flatten([for i in range(var.vpc_zone_count) : cidrsubnet(format("10.%d.0.0/21", count.index), 3, i + 5)])

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

module "vm" {
  count   = var.vpc_count
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.0.0"

  name                        = format("%s-vm-%02d", var.prefix, count.index)
  ami                         = data.aws_ami.ubuntu.id # OS: Ubuntu 20.04 - Username: ubuntu
  instance_type               = "m5.xlarge"
  subnet_id                   = module.vpc[count.index].public_subnets[0]
  associate_public_ip_address = true
  key_name                    = var.prefix

  tags = local.tags

}

module "eks" {
  count   = var.vpc_count
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20"

  cluster_name    = format("%s-eks-%02d", var.prefix, count.index)
  cluster_version = var.cluster_version

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id     = module.vpc[count.index].vpc_id
  subnet_ids = module.vpc[count.index].private_subnets

  eks_managed_node_group_defaults = {
    # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
    ami_type        = "AL2023_x86_64_STANDARD"
    instance_types  = ["m5.xlarge"]
    use_name_prefix = false
    create_schedule = true
    cloudinit_pre_nodeadm = [
      {
        content_type = "application/node.eks.aws"
        content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              instance:
                localStorage:
                  strategy: RAID0
          EOT        
      }
    ]

    tags = local.tags

    lifecycle = {
      ignore_changes = [
        # Ignore changes to the node group tags
        "tags",
        # Ignore changes to the node group scaling config
        "scaling_config",
      ]
    }
  }

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    system = {
      name                       = format("eks-%02d-system-ng", count.index)
      use_custom_launch_template = false
      min_size                   = 1
      max_size                   = 2
      desired_size               = 1
      schedules = {
        "start" = {
          schedule_action_name = "start"
          recurrence           = "0 7 * * 1-5" # CRON expression
          time_zone            = "US/Eastern"
          min_size             = 1
          max_size             = 2
          desired_size         = 1
        }
        "stop" = {
          schedule_action_name = "stop"
          recurrence           = "0 17 * * 1-5" # CRON expression
          time_zone            = "US/Eastern"
          min_size             = 0
          max_size             = 0
          desired_size         = 0
        }
      }
    }
    generic = {
      name                           = format("eks-%02d-default-ng", count.index)
      use_latest_ami_release_version = true
      min_size                       = 2
      max_size                       = 4
      desired_size                   = 2
      schedules = {
        "start" = {
          schedule_action_name = "start"
          recurrence           = "0 7 * * 1-5"
          time_zone            = "US/Eastern"
          min_size             = 2
          max_size             = 4
          desired_size         = 2
        }
        "stop" = {
          schedule_action_name = "stop"
          recurrence           = "0 17 * * 1-5"
          time_zone            = "US/Eastern"
          min_size             = 0
          max_size             = 0
          desired_size         = 0
        }
      }
    }
  }

  tags = local.tags

}

# Storage
module "ebs_csi_driver" {
  count  = var.vpc_count
  source = "./modules/ebs_csi_driver"

  cluster_name = format("%s-eks-%02d", var.prefix, count.index)
  tags         = local.tags
  oidc_url     = module.eks[count.index].cluster_oidc_issuer_url

  depends_on = [module.eks]
}

resource "aws_eks_addon" "aws-ebs-csi-driver" {
  count                       = var.vpc_count
  cluster_name                = module.eks[count.index].cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = module.ebs_csi_driver[count.index].ebs_csi_driver_role.arn

}

# Kubernetes
module "kubeconfig" {
  count        = var.vpc_count
  source       = "./modules/kubeconfig"
  prefix       = var.prefix
  region       = var.region
  path         = format("%s-kubeconfig-%02d.conf", var.prefix, count.index)
  cluster_name = module.eks[count.index].cluster_name
  endpoint     = module.eks[count.index].cluster_endpoint
  ca_crt       = module.eks[count.index].cluster_certificate_authority_data

  depends_on = [module.eks]
}

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

module "vpc" {
  count   = var.vpc_count
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = format("%s-vpc-%02d", var.prefix, count.index)
  cidr = format("10.%d.0.0/21", count.index)
  azs  = slice(data.aws_availability_zones.available.names, 0, var.vpc_zone_count)

  private_subnets = [for i in range(var.vpc_zone_count) : format("10.%d.%d.0/24", count.index, i + 1)]
  public_subnets  = [for i in range(var.vpc_zone_count) : format("10.%d.%d.0/24", count.index, i + var.vpc_zone_count + 1)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
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
}

module "eks" {
  count   = var.vpc_count
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

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
  }

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    system = {
      name                       = format("eks-%02d-system-ng", count.index)
      use_custom_launch_template = false
      min_size                   = 1
      max_size                   = 2
      desired_size               = 1
    }
    default = {
      name                           = format("eks-%02d-default-ng", count.index)
      use_latest_ami_release_version = true
      min_size                       = 2
      max_size                       = 4
      desired_size                   = 2
    }
  }

}

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

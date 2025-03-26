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

module "vm" {
  count = var.vpc_count
  source = "terraform-aws-modules/ec2-instance/aws"
  version = "3.0.0"

  name = format("%s-vm-%02d", var.prefix, count.index)
  ami = "ami-04f167a56786e4b09" # Ubuntu 24.04 - Username: ubuntu
  instance_type = "m5.xlarge"
  subnet_id = module.vpc[count.index].public_subnets[0]
  associate_public_ip_address = true
  key_name = var.prefix
}

module "eks" {
  count   = var.vpc_count
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = format("%s-eks-%02d", var.prefix, count.index)
  cluster_version = var.cluster_version

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  # cluster_addons = {
  #   aws-ebs-csi-driver = {
  #     service_account_role_arn = module.irsa-ebs-csi[count].iam_role_arn
  #   }
  # }
  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id     = module.vpc[count.index].vpc_id
  subnet_ids = module.vpc[count.index].private_subnets

  eks_managed_node_group_defaults = {
    # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
    ami_type        = "AL2023_x86_64_STANDARD"
    use_name_prefix = false
  }

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    system = {
      instance_types = ["m5.xlarge"]
      name           = format("eks-%02d-system-ng", count.index)

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
    default = {
      instance_types = ["m5.xlarge"]
      name           = format("eks-%02d-default-ng", count.index)

      min_size     = 2
      max_size     = 4
      desired_size = 2
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

# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
# data "aws_iam_policy" "ebs_csi_policy" {
#   arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
# }

# module "irsa-ebs-csi" {
#   count = var.vpc_count
#   source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
#   version = "5.39.0"

#   create_role                   = true
#   role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks[count.index].cluster_name}"
#   provider_url                  = module.eks[count.index].oidc_provider
#   role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
#   oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
# }

# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = var.region
}
/*
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
  }
}
*/

# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  cluster_name = var.cluster_name
  instance_type = var.instance_type
  min_size = var.min_size
  max_size = var.max_size
  desired_size = var.desired_size
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = "scoutflo-vpc-${random_string.suffix.result}"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  #private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  #enable_nat_gateway   = true
  #single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

 /*
  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
*/
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.5.1"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.public_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
    name_prefix = "${local.cluster_name}-nodegroup-" # Ensure this is short enough
  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = [local.instance_type]

      min_size     = local.min_size
      max_size     = local.max_size
      desired_size = local.desired_size
    }
/*
    two = {
      name = "node-group-2"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
*/
  }
}
    

# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.34.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.27.0-eksbuild.1"
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
  }
  depends_on = [module.eks]
  }
resource "aws_eks_addon" "kube-proxy" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "kube-proxy"
  addon_version            = "v1.29.0-eksbuild.1"
  resolve_conflicts        = "OVERWRITE"
  tags = {
    "eks_addon" = "kube-proxy"
    "terraform" = "true"
  }
  depends_on = [module.eks]
  }
resource "aws_eks_addon" "vpc-cni" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "vpc-cni"
  addon_version            = "v1.16.0-eksbuild.1"
  resolve_conflicts        = "OVERWRITE"
  tags = {
    "eks_addon" = "vpc-cni"
    "terraform" = "true"
  }
  depends_on = [module.eks]
  }
resource "aws_eks_addon" "coredns" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "coredns"
  addon_version            = "v1.10.1-eksbuild.6"
  resolve_conflicts        = "OVERWRITE"
  tags = {
    "eks_addon" = "coredns"
    "terraform" = "true"
  }
  depends_on = [module.eks]
  }
/*
 # Deploy NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://charts.helm.sh/stable"
  chart      = "nginx-ingress"
  version    = "1.41.3" # Check for the latest version

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  depends_on = [module.eks]
}

# Deploy Cert Manager
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.15.2" # Check for the latest version

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [module.eks]
}
*/

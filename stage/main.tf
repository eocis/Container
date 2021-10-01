terraform {
  backend "remote" {
    organization = "example-org-68bd7a"

    workspaces {
      name = "Container"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.5"
    }
  }

  required_version = ">= 1.0.5"
}

provider "aws" {
  region                  = "ap-northeast-2"     # Region
  shared_credentials_file = "~/.aws/credentials" # AWS Profile Path
}

locals {
  cluster_name = "EKS-cluster"
}

# Modules (VPC)

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  private_subnets = ["${var.subnets[2]}", "${var.subnets[3]}"]
  public_subnets  = ["${var.subnets[0]}", "${var.subnets[1]}"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"

  # ALB Ingress 설정을 위한 클러스터 이름 설정
  clusterName = local.cluster_name
  }

}

data "aws_eks_cluster" "eks" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"

  cluster_version = "1.21"
  cluster_name    = local.cluster_name
  vpc_id          = module.vpc.vpc_id
  subnets         = [module.vpc.private_subnets[0],module.vpc.private_subnets[1]]

  worker_groups = [
    {
      instance_type = "t3.medium"
      asg_desired_capacity = 2
      asg_max_size = 4
      asg_min_size = 2
      target_group_arns = module.alb.target_group_arns
    }

  
  ]
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name = "my-alb"

  load_balancer_type = "application"

  vpc_id             = module.vpc.vpc_id
  subnets            = [module.vpc.public_subnets[0],module.vpc.public_subnets[1]]
  security_groups    = ["${module.alb-sg.security_group_id}"]

  target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 443
      target_type      = "instance"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 443
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "Test"
  }
}

module "alb-sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "alb-sg"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks      = ["0.0.0.0/0"]
  ingress_rules            = ["https-443-tcp"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "10.0.0.0/16"
    }
  ]
}
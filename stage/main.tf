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


####################

# # Cluster (EKS)

# provider "kubernetes" {
#   host                   = data.aws_eks_cluster.eks.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
#   token                  = data.aws_eks_cluster_auth.eks.token
# }

# data "aws_eks_cluster" "eks" {
#   name = aws_eks_cluster.EKS-cluster.id
# }

# data "aws_eks_cluster_auth" "eks" {
#   name = aws_eks_cluster.EKS-cluster.id
# }

# resource "aws_eks_cluster" "EKS-cluster" {                  # Cluster
#   name                      = local.cluster_name
#   role_arn                  = aws_iam_role.cluster.arn

#   vpc_config {
#     subnet_ids = [module.vpc.private_subnets[0],module.vpc.private_subnets[1]]
#   }
# }

# resource "aws_launch_configuration" "EKS" {
#     associate_public_ip_address = true
#     instance_type = "t2.micro"  
#     name_prefix = "eks-node"

#     security_groups = [ aws_security_group.HTTP.id ]
#     image_id = data.aws_ami.eks-worker.id
# }

# resource "aws_autoscaling_group" "EKS-ND" {
#     desired_capacity = 2
#     launch_configuration = aws_launch_configuration.EKS.id
#     max_size = 2
#     min_size = 2
#     name = "EKS-ND"
#     vpc_zone_identifier = [
#         module.vpc.private_subnets[0],
#         module.vpc.private_subnets[1]
#         ]

#     target_group_arns = ["${aws_lb_target_group.alb-tg.arn}"]

#     tag {
#       key = "kubernetes.io/cluster/${local.cluster_name}"
#       value = "owned"
#       propagate_at_launch = true
#     }
# }

# # Node Group

# resource "aws_eks_node_group" "EKS_node_group" {
#     cluster_name = aws_eks_cluster.EKS-cluster.name
#     node_group_name = "EKS-node-group"
#     node_role_arn   = aws_iam_role.node_group.arn
#     subnet_ids = [
#         module.vpc.private_subnets[0],
#         module.vpc.private_subnets[1]
#     ]

#     scaling_config {
#       desired_size = 2
#       max_size = 2
#       min_size = 2
#     }

#     depends_on = [
#       aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
#       aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
#       aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly
#     ]
# }

# # Security Group

# resource "aws_security_group" "HTTP" {
#   name   = "access HTTP"
#   vpc_id = module.vpc.vpc_id

#   ingress = [{
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "goto node"
#     from_port        = 80
#     ipv6_cidr_blocks = null
#     prefix_list_ids  = null
#     protocol         = "tcp"
#     security_groups  = null
#     self             = false
#     to_port          = 3000
#   }]

#   egress = [{
#     cidr_blocks      = ["0.0.0.0/0"]
#     description      = "internet"
#     from_port        = 0
#     ipv6_cidr_blocks = null
#     prefix_list_ids  = null
#     protocol         = "-1"
#     security_groups  = null
#     self             = false
#     to_port          = 0
#   }]

# }

# resource "aws_lb_target_group" "alb-tg" {
#   name     = "ALB-TargetGroup"
#   port     = 443
#   protocol = "HTTPS"
#   vpc_id   = module.vpc.vpc_id
# }

# resource "aws_lb" "alb" {
#   name               = "ALB"
#   load_balancer_type = "application"
#   internal           = "false"
#   security_groups    = [aws_security_group.HTTP.id]
#   subnets = [
#     module.vpc.public_subnets[0],
#     module.vpc.public_subnets[1]
#   ]
# }

# resource "aws_lb_listener" "node" {
#   load_balancer_arn = aws_lb.alb.arn
#   port              = "3000"
#   protocol          = "HTTP"

#   default_action {
#     target_group_arn = aws_lb_target_group.alb-tg.id
#     type             = "forward"
#   }
# }
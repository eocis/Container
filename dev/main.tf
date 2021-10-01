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

# VPC

resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
}

# Subnets

resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.cidrs[0]
  availability_zone = data.aws_availability_zones.azs.names[0]
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.cidrs[1]
  availability_zone = data.aws_availability_zones.azs.names[2]
}

resource "aws_subnet" "private_subnet_3" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.cidrs[2]
  availability_zone = data.aws_availability_zones.azs.names[0]
}

resource "aws_subnet" "private_subnet_4" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.cidrs[3]
  availability_zone = data.aws_availability_zones.azs.names[2]
}

# Elastic IP
resource "aws_eip" "eip_ngw_1" {
  vpc = true
}

resource "aws_eip" "eip_ngw_2" {
  vpc = true
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

# NAT Gateway
resource "aws_nat_gateway" "ngw_1" {
  allocation_id = aws_eip.eip_ngw_1.id
  subnet_id     = aws_subnet.public_subnet_2.id
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "ngw_2" {
  allocation_id = aws_eip.eip_ngw_2.id
  subnet_id = aws_subnet.public_subnet_1.id
  depends_on = [aws_internet_gateway.igw]
  
}

# Route Tables

resource "aws_route_table" "route_table_public_igw" { # cidr: 0.0.0.0/0, target: igw
  vpc_id = aws_vpc.vpc.id

  route = [{
    cidr_block                 = "0.0.0.0/0"
    gateway_id                 = aws_internet_gateway.igw.id
    carrier_gateway_id         = null
    destination_prefix_list_id = null
    egress_only_gateway_id     = null
    instance_id                = null
    ipv6_cidr_block            = null
    local_gateway_id           = null
    nat_gateway_id             = null
    network_interface_id       = null
    transit_gateway_id         = null
    vpc_endpoint_id            = null
    vpc_peering_connection_id  = null
    }
  ]
}

resource "aws_route_table" "route_table_private_nat_1" {  # cidr: 0.0.0.0/0, target: nat_1
  vpc_id = aws_vpc.vpc.id

  route = [{
    cidr_block                 = "0.0.0.0/0"
    gateway_id                 = aws_nat_gateway.ngw_1.id
    carrier_gateway_id         = null
    destination_prefix_list_id = null
    egress_only_gateway_id     = null
    instance_id                = null
    ipv6_cidr_block            = null
    local_gateway_id           = null
    nat_gateway_id             = null
    network_interface_id       = null
    transit_gateway_id         = null
    vpc_endpoint_id            = null
    vpc_peering_connection_id  = null
  }]
}

resource "aws_route_table" "route_table_private_nat_2" {  # cidr: 0.0.0.0/0, target: nat_2
  vpc_id = aws_vpc.vpc.id

  route = [{
    cidr_block                 = "0.0.0.0/0"
    gateway_id                 = aws_nat_gateway.ngw_2.id
    carrier_gateway_id         = null
    destination_prefix_list_id = null
    egress_only_gateway_id     = null
    instance_id                = null
    ipv6_cidr_block            = null
    local_gateway_id           = null
    nat_gateway_id             = null
    network_interface_id       = null
    transit_gateway_id         = null
    vpc_endpoint_id            = null
    vpc_peering_connection_id  = null
  }]
}

resource "aws_route_table_association" "rt_associate_public_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.route_table_public_igw.id
}

resource "aws_route_table_association" "rt_associate_public_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.route_table_public_igw.id
}

resource "aws_route_table_association" "rt_associate_private_3_1" {
  subnet_id      = aws_subnet.private_subnet_3.id
  route_table_id = aws_route_table.route_table_private_nat_1.id
}

resource "aws_route_table_association" "rt_associate_private_3_2" {
  subnet_id      = aws_subnet.private_subnet_3.id
  route_table_id = aws_route_table.route_table_private_nat_1.id
}

# Security Group


resource "aws_security_group" "HTTP" { # Front-End Load Balancer SG
  name   = "access HTTP"
  vpc_id = aws_vpc.vpc.id

  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "access HTTP"
    from_port        = 80
    ipv6_cidr_blocks = null
    prefix_list_ids  = null
    protocol         = "tcp"
    security_groups  = null
    self             = false
    to_port          = 80
  }]

  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "internet"
    from_port        = 0
    ipv6_cidr_blocks = null
    prefix_list_ids  = null
    protocol         = "-1"
    security_groups  = null
    self             = false
    to_port          = 0
  }]

}

# Load Balancer

resource "aws_lb_target_group" "Front-End" { # Front-End Load Balancer
  name     = "Front-End-LB-TargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

}

resource "aws_lb" "Front-End" {
  name               = "Front-End-LB"
  load_balancer_type = "application"
  internal           = "false"
  security_groups    = [aws_security_group.HTTP.id]
  subnets = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]

  # access_logs {                                         # Access Log save as S3
  #   bucket = aws_s3_bucket.lb_logs.bucket
  #   prefix = "Front-End_Log"
  #   enabled = true
  # }
}

resource "aws_lb_listener" "Front-End" {
  load_balancer_arn = aws_lb.Front-End.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.Front-End.id
    type             = "forward"
  }
}

# IAM Role

resource "aws_iam_role" "eks_role" {    # IAM Role for EKS
  name = "eks-cluster-role"
  
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement":[
    {
    "Effect": "Allow",
    "Principal": {
      "Service": "eks.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
  ]
}
POLICY
}

# resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
#   policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AmazonEKSServicePolicy"
#   role = aws_iam_role.eks_role.name
  
# }

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.eks_role.name
  
}

resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role = aws_iam_role.eks_role.name
  
}

resource "aws_iam_role_policy_attachment" "AWSServiceRoleForAmazonEKSNodegroup" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSServiceRoleForAmazonEKSNodegroup"
  role = aws_iam_role.eks_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AmazonEKSServiceRolePolicy"
  role = aws_iam_role.eks_role.name
}

# EKS

resource "aws_eks_cluster" "eks_cluster" {
  name = "cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.private_subnet_3.id, aws_subnet.private_subnet_4.id]
  }


}

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-node-group"
  node_role_arn = aws_iam_role.eks_role.arn
  subnet_ids = [ aws_subnet.private_subnet_3.id, aws_subnet.private_subnet_4.id ]

  scaling_config {
    desired_size = 2
    max_size = 2
    min_size = 2
  }

  update_config {
    max_unavailable = 2
  }

  depends_on = [
    # aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
    aws_iam_role_policy_attachment.AmazonEKSServiceRolePolicy,
    aws_iam_role_policy_attachment.AWSServiceRoleForAmazonEKSNodegroup
  ]
  
}
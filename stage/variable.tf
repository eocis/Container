variable "aws_region" {
    type = string
    default = "ap-northeast-2"
}

variable "aws_azs" {
    type = string
    default = "ap-northeast-2a, ap-northeast-2c"
}

variable "az_count" {
    type = number
    default = 2
}

variable "vpc_cidr_base" {
    type = string
    default = "10.0"
  
}

variable "subnets" {
  type = map(string)
  default = {
    0 = "10.0.0.0/24"   # public 1
    1 = "10.0.1.0/24"   # public 2
    2 = "10.0.2.0/24"   # private 1
    3 = "10.0.3.0/24"   # private 2
  }
}

variable "aws-eks-node" {
    type = string
    default = "amazon-eks-node-1.21-v20210914"
}

variable "aws-eks-node-ami" {
    type = string
    default = "602401143452"
  
}

variable "lb_tg_arn" {
    type = string
    default = ""
}

variable "lb_tg_name" {
    type = string
    default = ""
}
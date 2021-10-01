data "aws_ami" "eks-worker" {
    filter{
        name = "name"
        values = ["${var.aws-eks-node}"]
    }

    most_recent = true
    owners = ["${var.aws-eks-node-ami}"]
  
}
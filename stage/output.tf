output "kubeconfig-certificate-authority-data" {
  value = "aws_eks_cluster.${local.cluster_name}.certificate_authority[0].data"
}

output "endpoint" {
  value = "aws_eks_cluster.${local.cluster_name}.endpoint"
}
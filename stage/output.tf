# Use Ingress-Controller
output "public_subnets" {
    value = module.vpc.public_subnets[*]
}
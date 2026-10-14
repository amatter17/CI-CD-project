output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group of the nodes and pods (managed node groups use it)."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_role_arn" {
  value = aws_iam_role.node.arn
}

# Anything that needs a working cluster (Helm releases) must depend on this
output "ready" {
  description = "Changes only when the cluster, nodes, add-ons and admin access exist."
  value = join(",", [
    aws_eks_node_group.this.id,
    aws_eks_addon.ebs_csi.id,
    join(",", [for a in aws_eks_addon.managed : a.id]),
    join(",", [for p in aws_eks_access_policy_association.admin : p.id]),
  ])
}

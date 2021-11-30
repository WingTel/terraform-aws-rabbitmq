# Security used by the nodes and share to the load balencer
output "security_group_id" {
  value = aws_security_group.rabbit-cluster.id
}

# Used by attachment target group
output "autoscaling_group" {
  value = aws_autoscaling_group.rabbit-node.id
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.rabbit-node.name
}

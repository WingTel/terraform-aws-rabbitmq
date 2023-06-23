output "security_group_id" {
  description = "Security used by the nodes and share to the load balencer"
  value       = aws_security_group.rabbit-cluster.id
}

output "autoscaling_group" {
  description = "Used by attachment target group"
  value       = aws_autoscaling_group.rabbit-node.id
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.rabbit-node.name
}

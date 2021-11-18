# Security used by the nodes and share to the load balencer
output "security_group_id" {
  value = aws_security_group.lb-external.id
}

# Used by attachment target group
output "autoscaling_group" {
  value = aws_autoscaling_group.rabbit-node.id
}

output "lb_dns_name" {
  value = aws_lb.lb_internal_net.dns_name
}

output "target_group_arns" {
  value       = [aws_lb_target_group.backend_mgmt_internal.arn, aws_lb_target_group.rabbitmq_internal.arn]
}

# Policies
resource "aws_iam_role" "ProxyRole" {
  name               = "${var.name}-rabbit-${var.environment}-role"
  assume_role_policy = file("${path.module}/policies/ProxyRole.json")
}

resource "aws_iam_instance_profile" "ProxyInstanceProfile" {
  name = "${var.name}-rabbit-${var.environment}-profile"
  role = aws_iam_role.ProxyRole.name
}

resource "aws_iam_role_policy" "ProxyPolicies" {
  name   = "${var.name}-rabbit-${var.environment}-proxy"
  policy = file("${path.module}/policies/ProxyPolicies.json")
  role   = aws_iam_role.ProxyRole.name
}

resource "aws_iam_role_policy" "CloudwatchPolicies" {
  name   = "${var.name}-rabbit-${var.environment}-cw-policies"
  policy = file("${path.module}/policies/CloudwatchPolicies.json")
  role   = aws_iam_role.ProxyRole.name
}

# SSM Agent Policies for Cloudwatch Logging
locals {
  role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

resource "aws_iam_instance_profile" "CloudwatchLogInstanceProfile" {
  name = "${var.name}-rabbit-${var.environment}-cw-log-profile"
  role = aws_iam_role.CloudwatchRole.name
}

resource "aws_iam_role_policy_attachment" "this" {
  count = length(local.role_policy_arns)
  role       = aws_iam_role.CloudwatchLogRole.name
  policy_arn = element(local.role_policy_arns, count.index)
}

resource "aws_iam_role_policy" "CloudwatchLogPolicies" {
  name = "${var.name}-rabbit-${var.environment}-cw-log-policies"
  role = aws_iam_role.CloudwatchLogRole.id
  policy = file("${path.module}/policies/CloudwatchLogPolicies.json")
}

resource "aws_iam_role" "CloudwatchLogRole" {
  name = "${var.name}-rabbit-${var.environment}-cw-log-profile"
  assume_role_policy = file("${path.module}/policies/CloudwatchRole.json")
}
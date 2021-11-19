# Policies
resource "aws_iam_role" "ProxyRole" {
  name               = "${var.name}-rabbit-${var.environment}"
  assume_role_policy = file("${path.module}/policies/ProxyRole.json")
}

resource "aws_iam_instance_profile" "ProxyInstanceProfile" {
  name = "${var.name}-rabbit-${var.environment}"
  role = aws_iam_role.ProxyRole.name
}

resource "aws_iam_role_policy" "ProxyPolicies" {
  name   = "${var.name}-rabbit-${var.environment}"
  policy = file("${path.module}/policies/ProxyPolicies.json")
  role   = aws_iam_role.ProxyRole.name
}

resource "aws_iam_role_policy" "CloudwatchPolicies" {
  name   = "${var.name}-rabbit-${var.environment}"
  policy = file("${path.module}/policies/CloudwatchPolicies.json")
  role   = aws_iam_role.ProxyRole.name
}

# SSM Agent Policies
locals {
  role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

resource "aws_iam_instance_profile" "this" {
  name = "EC2-Profile"
  role = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "this" {
  count = length(local.role_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = element(local.role_policy_arns, count.index)
}

resource "aws_iam_role_policy" "this" {
  name = "EC2-Inline-Policy"
  role = aws_iam_role.this.id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "ssm:GetParameter"
          ],
          "Resource" : "*"
        }
      ]
    }
  )
}

resource "aws_iam_role" "this" {
  name = "EC2-Role"
  path = "/"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "ec2.amazonaws.com"
          },
          "Effect" : "Allow"
        }
      ]
    }
  )
}
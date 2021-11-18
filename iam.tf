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

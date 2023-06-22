resource "aws_launch_template" "rabbit-node" {
  name_prefix            = "${var.name}-rabbit-${var.environment}-"
  image_id               = var.image_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  ebs_optimized          = var.instance_ebs_optimized
  user_data              = base64encode(data.template_file.rabbit-node.rendered)
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.ProxyInstanceProfile.name
  }

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    security_groups = [
      aws_security_group.rabbit-cluster.id,
      aws_security_group.rabbit-node.id,
    ]
  }

  block_device_mappings {
    device_name = data.aws_ami.image.root_device_name
    ebs {
      volume_type = var.root_volume_type
      volume_size = var.root_volume_size
    }
  }

  block_device_mappings {
    device_name = "/dev/xvdcz"
    ebs {
      volume_type = var.rabbit_volume_type
      volume_size = var.rabbit_volume_size
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "rabbit-node" {
  name = "${var.name}-rabbit-${var.environment}"

  vpc_zone_identifier  = var.external_subnets
  min_size             = var.autoscaling_min_size
  max_size             = var.autoscaling_max_size
  desired_capacity     = var.desired_capacity
  termination_policies = ["OldestLaunchTemplate", "Default"]
  target_group_arns    = var.target_group_arns

  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    name = aws_launch_template.rabbit-node.name
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-rabbit-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Cluster"
    value               = "${var.name}-${var.environment}-cluster"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "rabbit-node-scale-up" {
  name                   = "${var.name}-rabbit-${var.environment}-node-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.rabbit-node.name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "rabbit-node-scale-down" {
  name                   = "${var.name}-rabbit-${var.environment}-node-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.rabbit-node.name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_lifecycle_hook" "rabbit-node-upgrade" {
  name                   = "${var.name}-rabbit-${var.environment}-node-upgrade-hook"
  autoscaling_group_name = aws_autoscaling_group.rabbit-node.name
  default_result         = "CONTINUE"
  heartbeat_timeout      = 1200
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
}

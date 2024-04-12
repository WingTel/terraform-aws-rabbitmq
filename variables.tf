# ------------------------------------------------------
# General Settings
# ------------------------------------------------------
variable "environment" {
  description = "Desired environment to use in custom ids and names EG: \"staging\""
}

variable "name" {
  description = "The cluster name, e.g cdn"
}

variable "ssh_key_name" {
  description = "The aws ssh key name."
}

variable "region" {
  description = "The AWS region to create resources in."
}

variable "erl_secret_cookie" {
  description = "Used by rabbitmq to join a cluster"
}

variable "aws_access_key" {
  description = "Used by rabbitmq to describe autoscaling group"
}

variable "aws_secret_key" {
  description = "Used by rabbitmq to describe autoscaling group"
}

variable "rabbit_default_user" {
  description = "Default username to set for rabbit"
}

variable "rabbit_default_password" {
  description = "Default password to set for rabbit"
}

variable "cluster_fqdn" {}

# ------------------------------------------------------
#  EC2 parameters
# ------------------------------------------------------

variable "image_id" {
  description = "Ubuntu or Debian based image compatible with the start script (Use aws optimized ubuntu)"
}

variable "instance_type" {
  description = "Rabbit node type instance"
}

variable "instance_ebs_optimized" {
  description = "When set to true the instance will be launched with EBS optimized turned on"
}

variable "root_volume_type" {
  description = "The type of root volume. Can be standard, gp2, gp3, st1, sc1 or io1."
  type        = string
  default     = "gp2"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
}

variable "rabbit_volume_type" {
  description = "The type of rabbit volume. Can be standard, gp2, gp3, st1, sc1 or io1."
  type        = string
  default     = "gp2"
}

variable "rabbit_volume_size" {
  description = "Attached EBS volume size in GB - this is where docker data will be stored"
}

variable "rabbitmq_version" {
  description = "The version of the rabbitmq that you want install. To see all versions click this link: https://dl.bintray.com/rabbitmq/debian/dists/"
  default     = "main" # rabbitmq-server-v3.6.x, rabbitmq-server-v3.7.x, rabbitmq-server-v3.8.x/
}

variable "erlang_version" {
  description = "The version of the rabbitmq that you want install. To see all versions click this link: https://dl.bintray.com/rabbitmq-erlang/debian/dists/"
  default     = "erlang" # erlang-16.x, erlang-19.x, erlang-20.x, erlang-21.x, erlang-22.x
}

# ------------------------------------------------------
#  Network - VPC  parameters
# ------------------------------------------------------

variable "vpc_id" {
  description = "ID of the VPC to use"
}

variable "external_subnets" {
  description = "External subnets of the VPC"
  type        = list(string)
}

variable "associate_public_ip_address" {
  description = "Should created instances be publicly accessible (if the SG allows)"
}

# ------------------------------------------------------
#  Frontend Http
# ------------------------------------------------------
# variable "elb_id" {
#   description = "External ELB to use to balance the cluster"
# }

# Network Security
variable "ingress_public_cidr_blocks" {
  description = "A list of default CIDR blocks to allow traffic from (public usage)"
  type        = list(string)
}

variable "ingress_private_cidr_blocks" {
  description = "A list of CIDR block to allow traffic from (private usage)"
  type        = list(string)
}

variable "internet_public_cidr_blocks" {
  description = "Public outbount to access internet"
  type        = list(string)
}

# ------------------------------------------------------
#  Auto Scaling Group parameters
# ------------------------------------------------------

variable "desired_capacity" {
  description = "defined how many node you want in your autoscaling group"
}

variable "autoscaling_min_size" {
  description = "defined the minimum amount of the nodes you want in your autoscaling group"
}

variable "autoscaling_max_size" {
  description = "defined the maximum amount of the nodes you want in your autoscaling group"
}

variable "target_group_arns" {
  description = "target groups to be applied to auto scaling group"
}

# ------------------------------------------------------
#  CloudWatch parameters
# ------------------------------------------------------

variable "retention_in_days" {
  description = "Specifies the number of days you want to retain log events in the specified log group"
  type        = number
  default     = 5
}

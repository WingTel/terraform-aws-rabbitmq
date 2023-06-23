# Template use at launch to install docker
# It will also launch each docker container that are used to manage the state of our cluster
# This is used to pass required settings from terraform template directly in the EC2 instance
data "template_file" "rabbit-node" {
  template = file("${path.module}/user_data/rabbitmq.sh")

  vars = {
    AWS_REGION        = var.region
    VPC_ID            = var.vpc_id
    ERL_SECRET_COOKIE = var.erl_secret_cookie
    AWS_ACCESS_KEY    = var.aws_access_key
    AWS_SECRET_KEY    = var.aws_secret_key
    RABBITMQ_VERSION  = var.rabbitmq_version
    ERLANG_VERSION    = var.erlang_version
    CLUSTER_NAME      = "${var.cluster_fqdn}-${var.name}-${var.environment}"
    DEFAULT_USER      = var.rabbit_default_user
    DEFAULT_PASS      = var.rabbit_default_password
    ENVIRONMENT       = var.environment
    SERVICE_NAME      = var.name
  }
}

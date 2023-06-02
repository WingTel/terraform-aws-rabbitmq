![licence](https://img.shields.io/github/license/citizenplane/terraform-aws-rabbitmq.svg)

# Rabbitmq AWS Module
This repository is a set of two modules:
- One to create an Auto Scaling Group that will bind rabbitmq nodes together using the rabbitmq plugins:
  [rabbitmq_peer_discovery_aws](https://www.rabbitmq.com/cluster-formation.html#peer-discovery-aws)

- The other to declare two new entries on a private route53 zone, and bind them to a load balencer for the web interface management plugin
and the default rabbitmq TCP port in order to open new connections and channels.

  ![cloudcraft_schema](https://raw.githubusercontent.com/CitizenPlane/terraform-aws-rabbitmq/master/_docs/RabbitMQClusterAWS.png)

## How to use this Module

This module purpose is only to create a Rabbitmq Cluster and the routes to access it.
It does not include the creation of a *VPC* nor the *route53* zone used to access the Load balancer.

I'll let you refer to our other modules if you want to use them, otherwise it should be easy enough to plug this module in an already exisiting VPC (the alb beeing optional too).

Apart from the network, there is not much configuration to do as you can see in the example folder. Here are the main settings:

```hcl
module "rabbit" {
  source = "path/to/module"

  name         = "An useful name to identify your clustser"
  environment  = "Specify the environment (Prod/Staging/Test/whatever...)"

  # To bind the manager together, Rabbitmq uses the Erlang cookie so it knows they can join the cluster
  erl_secret_cookie = "a random secret key"
  # As we use the rabbit_peer_discovery_aws we need credentials that can inspect ec2 or asg groups

  # https://www.rabbitmq.com/cluster-formation.html#peer-discovery-aws
  aws_access_key = "KEY"

  aws_secret_key = "SECRET"

  # See example for full usage of this var, here it's pass so we can name the cluster rabbimtq
  # https://github.com/CitizenPlane/terraform-aws-rabbitmq/blob/dc123d34742202811455d1bea50cb5f779186d2f/user_data/rabbitmq.sh#L122
  cluster_fqdn = "test"

  region                 = "eu-west-3"
  ssh_key_name           = "ft_ssh_key"
  desired_capacity       = 3
  autoscaling_min_size   = 3
  autoscaling_max_size   = 5
  instance_ebs_optimized = false

  vpc_id = "vpc_id"

  # Subnets Zone where the ASG will create your EC2 instances
  external_subnets = ""

  root_volume_size   = 20 # /
  rabbit_volume_size = 50 # /var/lib/rabbitmq

  associate_public_ip_address = true

  # Note : AMI are region related. Make sure the AMI you choose is available in your region
  # https://cloud-images.ubuntu.com/locator/ec2/
  image_id = ""

  # You define the CIDR block that can reach your private ip in your VPC
  # Don't forget to include your EC2 instances
  # Any Network Interface that may need to access this cluster ECR ELB ALB .....
  ingress_private_cidr_blocks = [
    "192.x.x.x/24",
    "10.x.x.x/22",
    "172.x.x.x/16",
  ]

  # A set of Public IPs that can access the cluster from oustide your VPC
  # For instance, these will be used to restrict the Rabbitmq management web interface access
  ingress_public_cidr_blocks = [
    "88.x.x.x/32",
    "195.x.x.x/32",
  ]

  # This is egress only settings for traffic going outside your VPC. You may not want your cluster
  # to be able to reach any ip from oustide your network
  internet_public_cidr_blocks = [
    "0.0.0.0/0",
  ]

  instance_type = ""

  az_count = 3

  cpu_high_limit    = "70"
  cpu_low_limit     = "20"
  memory_high_limit = "70"
  memory_low_limit  = "20"
}
```


## CitizenPlane

*Starship Troopers narrator voice*:
Would you like to know more ? CitizenPlane is hiring take a look [here](https://www.notion.so/citizenplane/Current-offers-a29fe322e68c4fb4aa5cb6d628d49108)


<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Providers

| Name | Version |
|------|---------|
| aws | n/a |
| template | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| associate\_public\_ip\_address | Should created instances be publicly accessible (if the SG allows) | `any` | n/a | yes |
| autoscaling\_max\_size | defined the maximum amount of the nodes you want in your autoscaling group | `any` | n/a | yes |
| autoscaling\_min\_size | defined the minimum amount of the nodes you want in your autoscaling group | `any` | n/a | yes |
| aws\_access\_key | Used by rabbitmq to describe autoscaling group | `any` | n/a | yes |
| aws\_secret\_key | Used by rabbitmq to describe autoscaling group | `any` | n/a | yes |
| az\_count | Number of AZs to cover in a given AWS region | `any` | n/a | yes |
| cluster\_fqdn | n/a | `any` | n/a | yes |
| cpu\_high\_limit | Value of CPU Usage triggering a scale up | `any` | n/a | yes |
| cpu\_low\_limit | Value of CPU Usage triggering a scale down | `any` | n/a | yes |
| desired\_capacity | defined how many node you want in your autoscaling group | `any` | n/a | yes |
| environment | Desired environment to use in custom ids and names EG: "staging" | `any` | n/a | yes |
| erl\_secret\_cookie | Used by rabbitmq to join a cluster | `any` | n/a | yes |
| external\_subnets | External subnets of the VPC | `list(string)` | n/a | yes |
| image\_id | Ubuntu or Debian based image compatible with the start script (Use aws optimized ubuntu) | `any` | n/a | yes |
| ingress\_private\_cidr\_blocks | A list of CIDR block to allow traffic from (private usage) | `list(string)` | n/a | yes |
| ingress\_public\_cidr\_blocks | A list of default CIDR blocks to allow traffic from (public usage) | `list(string)` | n/a | yes |
| instance\_ebs\_optimized | When set to true the instance will be launched with EBS optimized turned on | `any` | n/a | yes |
| instance\_type | Rabbit node type instance | `any` | n/a | yes |
| internet\_public\_cidr\_blocks | Public outbount to access internet | `list(string)` | n/a | yes |
| name | The cluster name, e.g cdn | `any` | n/a | yes |
| rabbit\_default\_password | Default password to set for rabbit | `any` | n/a | yes |
| rabbit\_default\_user | Default username to set for rabbit | `any` | n/a | yes |
| rabbit\_volume\_size | Attached EBS volume size in GB - this is where docker data will be stored | `any` | n/a | yes |
| region | The AWS region to create resources in. | `any` | n/a | yes |
| root\_volume\_size | Root volume size in GB | `any` | n/a | yes |
| ssh\_key\_name | The aws ssh key name. | `any` | n/a | yes |
| target\_group\_arns | target groups to be applied to auto scaling group | `any` | n/a | yes |
| vpc\_id | ID of the VPC to use | `any` | n/a | yes |
| erlang\_version | The version of the rabbitmq that you want install. To see all versions click this link: https://dl.bintray.com/rabbitmq-erlang/debian/dists/ | `string` | `"erlang"` | no |
| rabbit\_volume\_type | The type of rabbit volume. Can be standard, gp2, gp3, st1, sc1 or io1. | `string` | `"gp2"` | no |
| rabbitmq\_version | The version of the rabbitmq that you want install. To see all versions click this link: https://dl.bintray.com/rabbitmq/debian/dists/ | `string` | `"main"` | no |
| root\_volume\_type | The type of root volume. Can be standard, gp2, gp3, st1, sc1 or io1. | `string` | `"gp2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| autoscaling\_group | Used by attachment target group |
| autoscaling\_group\_name | n/a |
| security\_group\_id | Security used by the nodes and share to the load balencer |


## Module development

Install git pre-commit hook from TF Modules CI.

TF Modules CI includes `pre-commit` hook for automatic documentation generation, fmt check etc.

### Install for Linux/MacOS

```shell script
mkdir -p .git/hooks && docker run --rm -e HOST_OS=${OSTYPE} nc-mss-app-docker.artifactory.corp.namecheap.net/nc/tf-modules-ci > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

### Install for Windows

Run the following script in `cmd` terminal.

```shell script
mkdir ".git\hooks" 2>NUL & docker run --rm -e HOST_OS=win nc-mss-app-docker.artifactory.corp.namecheap.net/nc/tf-modules-ci > .git\hooks\pre-commit
```
_Note: `PowerShell` and `git-bash` are not supported._


#### Check Docker settings for Windows

Allow `File sharing` for drive(s) with your code in `Docker` settings.

[Read more](https://docs.microsoft.com/en-us/visualstudio/containers/troubleshooting-docker-errors?view=vs-2019)

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->


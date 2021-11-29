#!/bin/bash

set -e          # exit on command errors
set -o nounset  # abort on unbound variable
set -o pipefail # capture fail exit codes in piped commands

# ----------------------------------------
# Mount EBS additional storage
# ----------------------------------------
export MOUNT_POINT=/var/lib/rabbitmq

apt-get -y update
apt-get -y install xfsprogs

INSTANCE_TYPE=$(wget -qO- http://169.254.169.254/latest/meta-data/instance-type | cut -d '.' -f1)
[[ $INSTANCE_TYPE = "t2" ]] && EBS_NAME="xvdcz" || EBS_NAME="nvme"

# If nitro based instances
if [[ $EBS_NAME = "nvme" ]]; then
  # Test which block is the ebs added volume it's the one returning `data`
  # since it's not yet formated and mounted
  # disable failsafe pipefail here so IS_NOT_ROOT can return 0
  set +o pipefail
  IS_NOT_ROOT=$(file -s /dev/nvme0n1 | grep "data" | wc -l)
  set -o pipefail
  [[ $IS_NOT_ROOT = "1" ]] && EBS_NAME="nvme0n1" || EBS_NAME="nvme1n1"
fi

# Following AWS procadure (https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-using-volumes.html)

mkfs -t xfs /dev/$EBS_NAME

# Where you which to mount the volume after (e.g: /var/lib/docker)
mkdir -p $MOUNT_POINT

# Mount the formated volume
mount /dev/$EBS_NAME $MOUNT_POINT

# Device is mounted now we shall protect against losing the device after reboot

EBS_UUID=$(blkid | grep $EBS_NAME | egrep '[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}' -o)

echo "UUID=$EBS_UUID $MOUNT_POINT xfs defaults,nofail 0 2" >> /etc/fstab

# ----------------------------------------
# Setpu Rabbitmq Configuration
# ----------------------------------------

export RANDOM_START=$(( ( RANDOM % 30 )  + 1 ))
export AWS_REGION="${AWS_REGION}"
export VPC_ID="${VPC_ID}"
export ERL_SECRET_COOKIE="${ERL_SECRET_COOKIE}"
export AWS_SECRET_KEY="${AWS_SECRET_KEY}"
export AWS_ACCESS_KEY="${AWS_ACCESS_KEY}"
export CLUSTER_NAME=${CLUSTER_NAME}
export RABBITMQ_VERSION=${RABBITMQ_VERSION}
export ERLANG_VERSION=${ERLANG_VERSION}
export DEFAULT_USER=${DEFAULT_USER}
export DEFAULT_PASS=${DEFAULT_PASS}
export ENVIRONMENT=${ENVIRONMENT}
export SERVICE_NAME=${SERVICE_NAME}

mkdir -p /etc/rabbitmq

echo -n $ERL_SECRET_COOKIE > /var/lib/rabbitmq/.erlang.cookie
chmod 600 /var/lib/rabbitmq/.erlang.cookie

cat << EndOfConfig >> /etc/rabbitmq/rabbitmq.conf
##
## Security, Access Control
## ==============
##

default_user = ${DEFAULT_USER}
default_pass = ${DEFAULT_PASS}
loopback_users.guest                           = false

## Networking
## ====================
##
## Related doc guide: https://rabbitmq.com/networking.html.
##
## By default, RabbitMQ will listen on all interfaces, using
## the standard (reserved) AMQP 0-9-1 and 1.0 port.
##

listeners.tcp.default                          = 5672
management.listener.port                       = 15672
management.listener.ssl                        = false


hipe_compile                                   = false

##
## Clustering
## =====================
##

cluster_formation.peer_discovery_backend       = rabbit_peer_discovery_aws
cluster_formation.aws.region                   = ${AWS_REGION}
cluster_formation.aws.access_key_id            = ${AWS_ACCESS_KEY}
cluster_formation.aws.secret_key               = ${AWS_SECRET_KEY}
cluster_formation.aws.use_autoscaling_group    = true


EndOfConfig

RABBITMQ_PLUGINS_FOLDER="/usr/lib/rabbitmq/plugins"

mkdir -p $RABBITMQ_PLUGINS_FOLDER

wget "https://github.com/noxdafox/rabbitmq-message-deduplication/releases/download/0.5.1/elixir-1.12.2.ez" -O "$RABBITMQ_PLUGINS_FOLDER/elixir-1.12.2.ez"
wget "https://github.com/noxdafox/rabbitmq-message-deduplication/releases/download/0.5.1/rabbitmq_message_deduplication-0.5.1.ez" -O "$RABBITMQ_PLUGINS_FOLDER/rabbitmq_message_deduplication-0.5.1.ez"
wget "https://github.com/Ayanda-D/rabbitmq-queue-master-balancer/releases/download/v0.0.5/rabbitmq_queue_master_balancer-0.0.5.ez" -O "$RABBITMQ_PLUGINS_FOLDER/rabbitmq_queue_master_balancer-0.0.5.ez"

RABBITMQ_PLUGINS="[rabbitmq_shovel,rabbitmq_shovel_management,rabbitmq_management,rabbitmq_peer_discovery_aws,rabbitmq_queue_master_balancer,rabbitmq_tracing,rabbitmq_message_deduplication]."

echo $RABBITMQ_PLUGINS > /etc/rabbitmq/enabled_plugins

# ----------------------------------------
# Install Rabbitmq
# ----------------------------------------
## The configuration bellow was inspired by the official rabbtimq installation guide.
## Link: https://www.rabbitmq.com/install-debian.html#apt-quick-start-cloudsmith

## Install prerequisites
apt-get install curl gnupg apt-transport-https -y

## Team RabbitMQ's main signing key
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null
## Cloudsmith: modern Erlang repository
curl -1sLf https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/gpg.E495BB49CC4BBE5B.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/io.cloudsmith.rabbitmq.E495BB49CC4BBE5B.gpg > /dev/null
## Cloudsmith: RabbitMQ repository
curl -1sLf https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/gpg.9F4587F226208342.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/io.cloudsmith.rabbitmq.9F4587F226208342.gpg > /dev/null

## Add apt repositories maintained by Team RabbitMQ
# sudo tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
# ## Provides modern Erlang/OTP releases
# ##
# deb [signed-by=/usr/share/keyrings/io.cloudsmith.rabbitmq.E495BB49CC4BBE5B.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/ubuntu bionic main
# deb-src [signed-by=/usr/share/keyrings/io.cloudsmith.rabbitmq.E495BB49CC4BBE5B.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/ubuntu bionic main

# ## Provides RabbitMQ
# ##
# deb [signed-by=/usr/share/keyrings/io.cloudsmith.rabbitmq.9F4587F226208342.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/ubuntu bionic main
# deb-src [signed-by=/usr/share/keyrings/io.cloudsmith.rabbitmq.9F4587F226208342.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/ubuntu bionic main
# EOF

## Add Bintray repositories that provision latest RabbitMQ and Erlang
tee /etc/apt/sources.list.d/bintray.rabbitmq.list <<EOF
## Installs erlang and rabbitmq respecting the versions configured versions by user
## To see versions you can use, look the variables.tf file.
deb https://dl.bintray.com/rabbitmq-erlang/debian $(lsb_release -sc) ${ERLANG_VERSION}
deb https://dl.bintray.com/rabbitmq/debian $(lsb_release -sc) ${RABBITMQ_VERSION}
EOF

## Update package indices
sudo apt-get update -y

## Install Erlang packages
sudo apt-get install -y erlang-base \
                        erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
                        erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
                        erlang-runtime-tools erlang-snmp erlang-ssl \
                        erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

## Install rabbitmq-server and its dependencies
sudo apt-get install rabbitmq-server -y --fix-missing

rabbitmqctl set_cluster_name ${CLUSTER_NAME}

# ----------------------------------------
# Configure cloudwatch agent
# ----------------------------------------

apt-get install collectd -y
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

cat << EndOfConfig >> /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 10,
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log",
    "run_as_user": "root",
    "region": "${AWS_REGION}"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/rabbitmq/**.log",
            "log_group_name":  "/${ENVIRONMENT}/${SERVICE_NAME}/rabbit",
            "log_stream_name": "{ip_address}_{instance_id}",
            "timestamp_format": "%d/%b/%Y:%H:%M:%S %z",
            "timezone": "Local"
          }
        ]
      }
    }
  }
}
EndOfConfig

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

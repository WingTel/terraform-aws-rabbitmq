#!/bin/bash

set -e          # exit on command errors
set -o nounset  # abort on unbound variable
set -o pipefail # capture fail exit codes in piped commands

# ----------------------------------------
# Mount EBS additional storage
# ----------------------------------------
export MOUNT_POINT=/var/lib/rabbitmq

# Debian 10 (buster) is EOL and its metadata is moved to archive.debian.org.
# Keep apt working by disabling the expired validity check and pointing to the archive URLs.
echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until
cat <<'EOF' > /etc/apt/sources.list
deb http://archive.debian.org/debian buster main
deb http://archive.debian.org/debian buster-updates main
deb http://archive.debian.org/debian-security buster/updates main
EOF

apt-get -y update || apt-get -o Acquire::Check-Valid-Until=false -y update
apt-get -y install xfsprogs

INSTANCE_TYPE=$(wget -qO- http://169.254.169.254/latest/meta-data/instance-type | cut -d '.' -f1)
[[ $INSTANCE_TYPE = "t2" ]] && EBS_NAME="xvdcz" || EBS_NAME="nvme"

# If nitro based instances, choose the extra EBS volume. The root volume is typically
# nvme1n1p1 and the attached data volume is already mounted /var/lib/rabbitmq in some
# instances, so retrying mkfs on a mounted XFS disk will fail.
if [[ $EBS_NAME = "nvme" ]]; then
  set +o pipefail
  for candidate in /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1; do
    if [[ ! -e "$candidate" ]]; then
      continue
    fi

    fs_type=$(blkid -o value -s TYPE "$candidate" 2>/dev/null || true)
    if [[ -n "$fs_type" && "$fs_type" == "xfs" ]] && mountpoint -q "$MOUNT_POINT"; then
      EBS_NAME="$${candidate#/dev/}"
      break
    fi

    if [[ -z "$fs_type" ]]; then
      EBS_NAME="$${candidate#/dev/}"
      break
    fi
  done
  set -o pipefail
fi

# Following AWS procedure (https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-using-volumes.html)
# Only format the device if it is not already an XFS filesystem.
if ! blkid /dev/$EBS_NAME 2>/dev/null | grep -qi 'TYPE="xfs"'; then
  mkfs -t xfs -f /dev/$EBS_NAME
fi

# Where you which to mount the volume after (e.g: /var/lib/docker)
mkdir -p "$MOUNT_POINT"

# Mount the formatted volume only if it is not already mounted
if ! mountpoint -q "$MOUNT_POINT"; then
  mount /dev/$EBS_NAME "$MOUNT_POINT"
fi

# Device is mounted now we shall protect against losing the device after reboot
EBS_UUID=$(blkid -s UUID -o value /dev/$EBS_NAME)

grep -q "^UUID=$EBS_UUID $MOUNT_POINT xfs" /etc/fstab || \
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
export CLUSTER_NAME="${CLUSTER_NAME}"
export RABBITMQ_VERSION="${RABBITMQ_VERSION}"
export ERLANG_VERSION="${ERLANG_VERSION}"
export DEFAULT_USER="${DEFAULT_USER}"
export DEFAULT_PASS="${DEFAULT_PASS}"
export ENVIRONMENT="${ENVIRONMENT}"
export SERVICE_NAME="${SERVICE_NAME}"

mkdir -p /etc/rabbitmq

# The rabbitmq system user is created by the Debian package install, but this script
# can run before that on a fresh instance. Ensure it exists before any ownership change.
if ! id -u rabbitmq >/dev/null 2>&1; then
  useradd --system --home-dir /var/lib/rabbitmq --shell /usr/sbin/nologin rabbitmq
fi

# rabbitmq-env.conf must be shell syntax only. Do not place "default_user = ..." here.
cat <<EOF > /etc/rabbitmq/rabbitmq-env.conf
RABBITMQ_DEFAULT_USER=${DEFAULT_USER}
RABBITMQ_DEFAULT_PASS=${DEFAULT_PASS}
RABBITMQ_ERLANG_COOKIE=${ERL_SECRET_COOKIE}
EOF
chown rabbitmq:rabbitmq /etc/rabbitmq/rabbitmq-env.conf
chmod 640 /etc/rabbitmq/rabbitmq-env.conf

# Store the Erlang cookie in the expected RabbitMQ location.
echo -n "${ERL_SECRET_COOKIE}" > /var/lib/rabbitmq/.erlang.cookie
chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
chmod 600 /var/lib/rabbitmq/.erlang.cookie

# rabbitmq.conf is the proper file for broker settings (key = value format).
cat <<EOF > /etc/rabbitmq/rabbitmq.conf
##
## Security, Access Control
## ==============
##

default_user = ${DEFAULT_USER}
default_pass = ${DEFAULT_PASS}
loopback_users.guest = false

## Networking
## ====================
##

listeners.tcp.default = 5672
management.listener.port = 15672
management.listener.ssl = false

hipe_compile = false
consumer_timeout = 86400000

##
## Clustering
## =====================
##

cluster_formation.peer_discovery_backend = rabbit_peer_discovery_aws
cluster_formation.aws.region = ${AWS_REGION}
cluster_formation.aws.access_key_id = ${AWS_ACCESS_KEY}
cluster_formation.aws.secret_key = ${AWS_SECRET_KEY}
cluster_formation.aws.use_autoscaling_group = true
EOF
chown rabbitmq:rabbitmq /etc/rabbitmq/rabbitmq.conf
chmod 640 /etc/rabbitmq/rabbitmq.conf

RABBITMQ_PLUGINS_FOLDER="/usr/lib/rabbitmq/plugins"
mkdir -p "$RABBITMQ_PLUGINS_FOLDER"

# Keep only plugins that are known to be compatible with the Debian 10 RabbitMQ package.
# The message-deduplication plugin was built for a newer Erlang runtime and crashes the broker
# during startup with: "plugin_built_with_incompatible_erlang".
# The queue master balancer plugin may also be version-sensitive; if compatibility issues appear,
# keep the base RabbitMQ plugins only and reintroduce extras one by one.
if [ -n "$${RABBITMQ_PLUGIN_QUEUE_MASTER_BALANCER:-}" ] && [ "$${RABBITMQ_PLUGIN_QUEUE_MASTER_BALANCER}" = "true" ]; then
  wget "https://github.com/Ayanda-D/rabbitmq-queue-master-balancer/releases/download/v0.0.5/rabbitmq_queue_master_balancer-0.0.5.ez" -O "$RABBITMQ_PLUGINS_FOLDER/rabbitmq_queue_master_balancer-0.0.5.ez"
fi

PLUGIN_LIST="[rabbitmq_shovel,rabbitmq_shovel_management,rabbitmq_management,rabbitmq_peer_discovery_aws"
if [ -n "$${RABBITMQ_PLUGIN_QUEUE_MASTER_BALANCER:-}" ] && [ "$${RABBITMQ_PLUGIN_QUEUE_MASTER_BALANCER}" = "true" ]; then
  PLUGIN_LIST="$${PLUGIN_LIST},rabbitmq_queue_master_balancer"
fi
PLUGIN_LIST="$${PLUGIN_LIST}]."

cat <<EOF > /etc/rabbitmq/enabled_plugins
$${PLUGIN_LIST}
EOF
chown rabbitmq:rabbitmq /etc/rabbitmq/enabled_plugins
chmod 640 /etc/rabbitmq/enabled_plugins

# ----------------------------------------
# Install Rabbitmq
# ----------------------------------------
## The configuration bellow was inspired by the official rabbtimq installation guide.
## Link: https://www.rabbitmq.com/install-debian.html#apt-quick-start-cloudsmith

## Install prerequisites
apt-get install curl gnupg apt-transport-https -y

## Debian 10 (buster) is EOL and the newer Team RabbitMQ/Cloudsmith repositories
## do not publish a working buster key/repo set. Use the stock Debian 10 packages
## instead to avoid the 404 key and repository errors seen in cloud-init.
##
## If a newer RabbitMQ version is required, the instance should be migrated off
## Debian 10 to a supported release, because the RabbitMQ Team no longer keeps
## a functional buster repository.

## Update package indices from the Debian 10 archive mirror
sudo apt-get -o Acquire::Check-Valid-Until=false update -y

## Install the RabbitMQ package from Debian 10 repositories
sudo apt-get install -y rabbitmq-server

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

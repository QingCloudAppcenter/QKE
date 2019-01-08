#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/scripts/ha/runtime/common.sh"

echo "root:k8s" |chpasswd
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
mv /root/.ssh/authorized_keys /data
ln -fs /data/authorized_keys /root/.ssh/authorized_keys
systemctl restart ssh
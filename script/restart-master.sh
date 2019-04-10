#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

systemctl restart docker
systemctl restart kubelet

# Mark Master
echo "Mark Master"
kubeadm alpha phase mark-master --node-name ${HOST_INSTANCE_ID}
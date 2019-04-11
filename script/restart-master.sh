#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

systemctl restart docker
systemctl restart kubelet

# Mark Master
echo "Mark Master"
kubeadm init phase mark-control-plane --node-name ${HOST_INSTANCE_ID}
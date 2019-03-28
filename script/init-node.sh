#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
echo "===start init node==="
link_dir
swapoff -a

systemctl restart docker
is_systemd_active docker

if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    cat /etc/kubernetes/kubeadm-config.yaml
fi
echo "===end init node==="
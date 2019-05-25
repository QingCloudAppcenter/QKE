#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

echo $(date "+%Y-%m-%d %H:%M:%S") "===start init node==="
echo $(date "+%Y-%m-%d %H:%M:%S") "link dir"
link_dir
echo $(date "+%Y-%m-%d %H:%M:%S") "swapoff"
swapoff -a
echo $(date "+%Y-%m-%d %H:%M:%S") "touch lb file"
touch /etc/kubernetes/loadbalancer_ip
echo $(date "+%Y-%m-%d %H:%M:%S") "restart docker"
systemctl restart docker
is_systemd_active docker
echo $(date "+%Y-%m-%d %H:%M:%S") "finish restart docker"

if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    echo $(date "+%Y-%m-%d %H:%M:%S") "read kubeadm config"
    cat /etc/kubernetes/kubeadm-config.yaml
fi
echo $(date "+%Y-%m-%d %H:%M:%S") "===end init node==="
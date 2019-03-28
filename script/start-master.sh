#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
echo "===start start master==="
swapoff -a
ensure_dir

if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    cat /etc/kubernetes/kubeadm-config.yaml
fi

echo "===end start master==="
# Reload config
systemctl daemon-reload

# Start etcd
if [ "${CLUSTER_ETCD_ID}" == "null" ]
then
    retry systemctl start etcd
    is_systemd_active etcd
fi

# Start Docker
retry systemctl restart docker
is_systemd_active docker

# Start Kubelet
retry systemctl start kubelet
is_systemd_active kubelet



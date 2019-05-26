#!/usr/bin/env bash
echo $(date "+%Y-%m-%d %H:%M:%S") "===start start master==="
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
echo $(date "+%Y-%m-%d %H:%M:%S") "swapoff"
swapoff -a
echo $(date "+%Y-%m-%d %H:%M:%S") "ensure dir"
ensure_dir

if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    echo $(date "+%Y-%m-%d %H:%M:%S") "read kubeadm config"
    cat /etc/kubernetes/kubeadm-config.yaml
fi

# Reload config
echo $(date "+%Y-%m-%d %H:%M:%S") "daemon reload"
systemctl daemon-reload

# Start etcd
if [ "${CLUSTER_ETCD_ID}" == "null" ]
then
    echo $(date "+%Y-%m-%d %H:%M:%S") "start etcd"
    retry systemctl start etcd
    is_systemd_active etcd
    echo $(date "+%Y-%m-%d %H:%M:%S") "finish starting etcd"
fi

# Start Docker
echo $(date "+%Y-%m-%d %H:%M:%S") "start docker"
retry systemctl restart docker
is_systemd_active docker
echo $(date "+%Y-%m-%d %H:%M:%S") "finish starting docker"

# Start Kubelet
echo $(date "+%Y-%m-%d %H:%M:%S") "start kubelet"
retry systemctl restart kubelet
is_systemd_active kubelet
echo $(date "+%Y-%m-%d %H:%M:%S") "finish starting docker"

echo $(date "+%Y-%m-%d %H:%M:%S") "===end start master==="



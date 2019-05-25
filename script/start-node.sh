#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
echo $(date "+%Y-%m-%d %H:%M:%S") "===start start node==="
echo $(date "+%Y-%m-%d %H:%M:%S") "swapoff"
swapoff -a
echo $(date "+%Y-%m-%d %H:%M:%S") "ensure dir"
ensure_dir

# Start Docker
echo $(date "+%Y-%m-%d %H:%M:%S") "start docker"
retry systemctl start docker
is_systemd_active docker
echo $(date "+%Y-%m-%d %H:%M:%S") "finish starting docker"

echo $(date "+%Y-%m-%d %H:%M:%S") "join node"
join_node
echo $(date "+%Y-%m-%d %H:%M:%S") "finish joining node"

# Write kubelet configuration to file "/var/lib/kubelet/config.yaml"
# Write kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
echo $(date "+%Y-%m-%d %H:%M:%S") "write kubelet config"
kubeadm init phase kubelet-start --config  ${KUBEADM_CONFIG_PATH}
echo $(date "+%Y-%m-%d %H:%M:%S") "finish writing kubelet config"

# Reload config
echo $(date "+%Y-%m-%d %H:%M:%S") "daemon reload"
systemctl daemon-reload

# Start Kubelet
echo $(date "+%Y-%m-%d %H:%M:%S") "restart kubelet"
retry systemctl restart kubelet
is_systemd_active kubelet

if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    echo $(date "+%Y-%m-%d %H:%M:%S") "cat kubeadm config"
    cat /etc/kubernetes/kubeadm-config.yaml
fi
echo $(date "+%Y-%m-%d %H:%M:%S") "===end start node==="
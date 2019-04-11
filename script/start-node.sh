#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
echo "===start start node==="
swapoff -a
ensure_dir

# Start Docker
retry systemctl restart docker
is_systemd_active docker

join_node

# Write kubelet configuration to file "/var/lib/kubelet/config.yaml"
# Write kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
kubeadm init phase kubelet-start --config  ${KUBEADM_CONFIG_PATH}

# Reload config
systemctl daemon-reload

# Start Docker
retry systemctl restart docker
is_systemd_active docker

# Start Kubelet
retry systemctl restart kubelet
is_systemd_active kubelet

if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    cat /etc/kubernetes/kubeadm-config.yaml
fi
echo "===end start node==="
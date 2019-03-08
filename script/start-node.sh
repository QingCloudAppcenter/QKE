#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

swapoff -a
ensure_dir

# Start Docker
retry systemctl restart docker
is_systemd_active docker

join_node

# Write kubelet configuration to file "/var/lib/kubelet/config.yaml"
kubeadm alpha phase kubelet config write-to-disk --config ${KUBEADM_CONFIG_PATH}
# Write kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
kubeadm alpha phase kubelet write-env-file --config ${KUBEADM_CONFIG_PATH}

# Reload config
systemctl daemon-reload

# Start Docker
retry systemctl restart docker
is_systemd_active docker

# Start Kubelet
retry systemctl restart kubelet
is_systemd_active kubelet
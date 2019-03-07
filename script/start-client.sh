#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
export KUBECONFIG="/etc/kubernetes/admin.conf"

rm /root/.ssh/authorized_keys
ln -fs /data/authorized_keys /root/.ssh/authorized_keys

swapoff -a

# Install Addons
echo "Install Kube-Proxy"
retry kubeadm alpha phase addon kube-proxy --config ${KUBEADM_CONFIG_PATH}
# Mark Master
echo "Mark Master"
kubeadm alpha phase mark-master --node-name ${MASTER_1_INSTANCE_ID}
kubeadm alpha phase mark-master --node-name ${MASTER_2_INSTANCE_ID}
kubeadm alpha phase mark-master --node-name ${MASTER_3_INSTANCE_ID}

# Install Network Plugin
echo "Install Network Plugin"
install_network_plugin
echo "Install Coredns"
# Install Coredns
install_coredns
# Install Storage Plugin
echo "Install CSI"
install_csi
# Install Tiller
echo "Install Tiller"
install_tiller
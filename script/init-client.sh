#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

link_dir
set_password

retry scp root@master1:/etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/ca.crt
retry scp root@master1:/root/.kube/config /root/.kube/config

sleep 60
# Create a ConfigMap "kubelet-config-1.12" in namespace kube-system with the configuration for the kubelets in the cluster
retry kubeadm alpha phase kubelet config upload --config ${KUBEADM_CONFIG_PATH}
# storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
retry kubeadm alpha phase upload-config --config ${KUBEADM_CONFIG_PATH}
# Marking the current node as master 
retry kubeadm alpha phase mark-master  --node-name ${MASTER_1_INSTANCE_ID}
retry kubeadm alpha phase mark-master  --node-name ${MASTER_2_INSTANCE_ID}
retry kubeadm alpha phase mark-master  --node-name ${MASTER_3_INSTANCE_ID}
# Create Token
retry kubeadm alpha phase bootstrap-token all --config ${KUBEADM_CONFIG_PATH}
# Install Network Plugin
install_network_plugin
# Install Addons
retry kubeadm alpha phase addon all --config ${KUBEADM_CONFIG_PATH}
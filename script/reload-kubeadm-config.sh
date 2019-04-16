#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

if [ ${ENV_MASTER_COUNT} -gt 1 ]
then
    replace_kubeadm_config_lb_ip
fi
# Write kubelet configuration to file "/var/lib/kubelet/config.yaml"
# Write kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
kubeadm init phase kubelet-start --config  ${KUBEADM_CONFIG_PATH}

if [ "${HOST_ROLE}" == "master" ]
then
    # Write Static Pod manifest
    kubeadm init phase control-plane all --config ${KUBEADM_CONFIG_PATH}
    if [ "${HOST_SID}" == "1" ]
    then
        # storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
        retry kubeadm init phase upload-config kubeadm --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
        # Creating a ConfigMap "kubelet-config-1.13" in namespace kube-system with the configuration for the kubelets in the cluster
        retry kubeadm init phase upload-config kubelet --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    fi
fi

# Reload config
systemctl daemon-reload
systemctl restart kubelet
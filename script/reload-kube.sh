#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"


# Write kubelet configuration to file "/var/lib/kubelet/config.yaml"
kubeadm alpha phase kubelet config write-to-disk --config ${KUBEADM_CONFIG_PATH}
# Write kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
kubeadm alpha phase kubelet write-env-file --config ${KUBEADM_CONFIG_PATH}

if [ "${HOST_ROLE}" == "master" ]
then
    # Write Static Pod manifest
    kubeadm alpha phase controlplane all --config ${KUBEADM_CONFIG_PATH}
    if [ "${HOST_SID}" == "1" ]
    then
        # Create a ConfigMap "kubelet-config-1.12" in namespace kube-system with the configuration for the kubelets in the cluster
        kubeadm alpha phase kubelet config upload --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBE_LOCAL_CONF}
        # storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
        kubeadm alpha phase upload-config --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBE_LOCAL_CONF}
    fi
fi

# Reload config
systemctl daemon-reload
systemctl restart kubelet


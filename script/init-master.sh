#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
source "${K8S_HOME}/script/loadbalancer-manager.sh"

echo "===start init master==="
link_dir
swapoff -a
touch /etc/kubernetes/loadbalancer_ip
systemctl restart docker
is_systemd_active docker

if [ "${ENV_MASTER_COUNT}" == "3" ]
then
    replace_kubeadm_config_lb_ip
    replace_hosts_lb_ip
fi

if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    cat /etc/kubernetes/kubeadm-config.yaml
fi
echo "===end init master==="

if [ "${CLUSTER_ETCD_ID}" == "null" ]
then
    systemctl daemon-reload
    retry systemctl start etcd
    is_systemd_active etcd
fi

if [ "${HOST_SID}" == "1" ]
then
    # Create Common Cert Files
    kubeadm alpha phase certs ca --config ${KUBEADM_CONFIG_PATH} 
    kubeadm alpha phase certs sa --config ${KUBEADM_CONFIG_PATH}
    kubeadm alpha phase certs front-proxy-ca --config ${KUBEADM_CONFIG_PATH}
    # Copy Cert to Other Master
    cat << EOF > /etc/kubernetes/certificate_files.txt
/etc/kubernetes/pki/ca.crt
/etc/kubernetes/pki/ca.key
/etc/kubernetes/pki/sa.key
/etc/kubernetes/pki/sa.pub
/etc/kubernetes/pki/front-proxy-ca.crt
/etc/kubernetes/pki/front-proxy-ca.key
EOF
    tar -czf /etc/kubernetes/control-plane-certificates.tar.gz -T /etc/kubernetes/certificate_files.txt
    if [ "${ENV_MASTER_COUNT}" == "3" ]
    then
        scp /etc/kubernetes/control-plane-certificates.tar.gz root@${MASTER_2_INSTANCE_ID}:/etc/kubernetes
        scp /etc/kubernetes/control-plane-certificates.tar.gz root@${MASTER_3_INSTANCE_ID}:/etc/kubernetes
    fi
else
    # Get control plane cert files
    while [ -z "/etc/kubernetes/control-plane-certificates.tar.gz" ]
    do
        echo "sleep for wait cert files"
        sleep 2
    done
    retry tar -xzf /etc/kubernetes/control-plane-certificates.tar.gz -C /etc/kubernetes/pki --strip-components 3
fi

# Create Cert Files
kubeadm alpha phase certs apiserver --config ${KUBEADM_CONFIG_PATH} 
kubeadm alpha phase certs apiserver-kubelet-client --config ${KUBEADM_CONFIG_PATH}
kubeadm alpha phase certs front-proxy-client --config ${KUBEADM_CONFIG_PATH}
# Write KubeConfig file to disk
kubeadm alpha phase kubeconfig all --config ${KUBEADM_CONFIG_PATH}
# Write kubelet configuration to file "/var/lib/kubelet/config.yaml"
kubeadm alpha phase kubelet config write-to-disk --config ${KUBEADM_CONFIG_PATH}
# Write kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
kubeadm alpha phase kubelet write-env-file --config ${KUBEADM_CONFIG_PATH}
# Write Static Pod manifest
kubeadm alpha phase controlplane all --config ${KUBEADM_CONFIG_PATH}

# Start Kubelet
systemctl daemon-reload
retry systemctl restart kubelet
is_systemd_active kubelet

retry kubectl get nodes

if [ "${HOST_SID}" == "1" ]
then
    # Create a ConfigMap "kubelet-config-1.12" in namespace kube-system with the configuration for the kubelets in the cluster
    retry kubeadm alpha phase kubelet config upload --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    # storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
    retry kubeadm alpha phase upload-config --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    # Create Token
    echo "Create Token"
    retry kubeadm alpha phase bootstrap-token all --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    # Install Addons
    echo "Install Kube-Proxy"
    retry install_kube_proxy
    # Install Network Plugin
    echo "Install Network Plugin"
    retry install_network_plugin
    echo "Install Coredns"
    # Install Coredns
    retry install_coredns
    # Install Storage Plugin
    echo "Install CSI"
    retry install_csi
    # Install Tiller
    echo "Install Tiller"
    retry install_tiller
    echo "Install Cloud Controller Manager"
    retry install_cloud_controller_manager
fi

# Mark Master
echo "Mark Master"
kubeadm alpha phase mark-master --node-name ${HOST_INSTANCE_ID}
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

if [ ${ENV_MASTER_COUNT} -gt 1 ]
then
    replace_kubeadm_config_lb_ip
    replace_hosts_lb_ip
fi

if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    cat /etc/kubernetes/kubeadm-config.yaml
fi

if [ "${CLUSTER_ETCD_ID}" == "null" ]
then
    systemctl daemon-reload
    retry systemctl start etcd
    is_systemd_active etcd
fi

if [ "${HOST_SID}" == "1" ]
then
    # Create Common Cert Files
    kubeadm init phase certs ca --config ${KUBEADM_CONFIG_PATH} 
    kubeadm init phase certs sa
    kubeadm init phase certs front-proxy-ca --config ${KUBEADM_CONFIG_PATH}
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
    for((i=2;i<=${ENV_MASTER_COUNT};i++));
    do
        scp /etc/kubernetes/control-plane-certificates.tar.gz root@$(eval echo '$'"MASTER_${i}_INSTANCE_ID"):/etc/kubernetes
    done
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
kubeadm init phase certs apiserver --config ${KUBEADM_CONFIG_PATH} 
kubeadm init phase certs apiserver-kubelet-client --config ${KUBEADM_CONFIG_PATH}
kubeadm init phase certs front-proxy-client --config ${KUBEADM_CONFIG_PATH}
# Write KubeConfig file to disk
kubeadm init phase kubeconfig all --config ${KUBEADM_CONFIG_PATH}
# Set Kubelet Args
# Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
# Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
# Restart the kubelet service 
kubeadm init phase kubelet-start --config ${KUBEADM_CONFIG_PATH}
# Write Static Pod manifest
kubeadm init phase control-plane all --config ${KUBEADM_CONFIG_PATH}

# Start Kubelet
systemctl daemon-reload
retry systemctl restart kubelet
is_systemd_active kubelet

retry kubectl get nodes --kubeconfig /etc/kubernetes/admin.conf

if [ "${HOST_SID}" == "1" ]
then
    # storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
    retry kubeadm init phase upload-config kubeadm --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    # Creating a ConfigMap "kubelet-config-1.13" in namespace kube-system with the configuration for the kubelets in the cluster
    retry kubeadm init phase upload-config kubelet --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    # Create Token
    echo "Create Token"
    retry kubeadm init phase bootstrap-token --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    # Install Addons
    echo "Install Kube-Proxy"
    retry install_kube_proxy
    # Install Network Plugin
    echo "Install Network Plugin"
    retry install_network_plugin
    # Install Coredns
    echo "Install Coredns"
    retry install_coredns
    # Install Storage Plugin
    echo "Install CSI"
    retry install_csi
    # Install Tiller
    echo "Install Tiller"
    retry install_tiller
fi

# Mark Master
echo "Mark Master"
kubeadm init phase mark-control-plane --node-name ${HOST_INSTANCE_ID}

echo "===end init master==="
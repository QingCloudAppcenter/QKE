#!/usr/bin/env bash
echo $(date "+%Y-%m-%d %H:%M:%S") "===start init master===" 
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
source "${K8S_HOME}/script/loadbalancer-manager.sh"

echo $(date "+%Y-%m-%d %H:%M:%S") "link dir" 
link_dir
echo $(date "+%Y-%m-%d %H:%M:%S") "swapoff" 
swapoff -a
echo $(date "+%Y-%m-%d %H:%M:%S") "touch lb ip file" 
touch /etc/kubernetes/loadbalancer_ip
echo $(date "+%Y-%m-%d %H:%M:%S") "systemctl restart docker" 
systemctl restart docker
echo $(date "+%Y-%m-%d %H:%M:%S") "is docker active" 
is_systemd_active docker
echo $(date "+%Y-%m-%d %H:%M:%S") "docker active" 

if [ ${ENV_MASTER_COUNT} -gt 1 ]
then
    echo $(date "+%Y-%m-%d %H:%M:%S") "replace kubeadm config lb ip" 
    replace_kubeadm_config_lb_ip
    echo $(date "+%Y-%m-%d %H:%M:%S") "replace hosts lb ip" 
    replace_hosts_lb_ip
fi

echo $(date "+%Y-%m-%d %H:%M:%S") "is kubeadm config file exist" 
if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    cat /etc/kubernetes/kubeadm-config.yaml
fi

if [ "${CLUSTER_ETCD_ID}" == "null" ]
then
    echo $(date "+%Y-%m-%d %H:%M:%S") "start etcd" 
    systemctl daemon-reload
    retry systemctl start etcd
    is_systemd_active etcd
    echo $(date "+%Y-%m-%d %H:%M:%S") "finish start etcd" 
fi

if [ "${HOST_SID}" == "1" ]
then
    # Create Common Cert Files
    echo $(date "+%Y-%m-%d %H:%M:%S") "create ca files" 
    kubeadm init phase certs ca --config ${KUBEADM_CONFIG_PATH} 
    kubeadm init phase certs sa
    kubeadm init phase certs front-proxy-ca --config ${KUBEADM_CONFIG_PATH}
    # Copy Cert to Other Master
    echo $(date "+%Y-%m-%d %H:%M:%S") "copy ca to other masters" 
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
    echo $(date "+%Y-%m-%d %H:%M:%S") "finish copy ca to other masters" 
else
    # Get control plane cert files
    echo $(date "+%Y-%m-%d %H:%M:%S") "waiting for ca files" 
    while [ -z "/etc/kubernetes/control-plane-certificates.tar.gz" ]
    do
        echo "sleep for wait cert files"
        sleep 2
    done
    echo $(date "+%Y-%m-%d %H:%M:%S") "finish receiving ca files"
    retry tar -xzf /etc/kubernetes/control-plane-certificates.tar.gz -C /etc/kubernetes/pki --strip-components 3
    echo $(date "+%Y-%m-%d %H:%M:%S") "finish extracting ca files"
fi

# Create Cert Files
echo $(date "+%Y-%m-%d %H:%M:%S") "start init certs"
kubeadm init phase certs apiserver --config ${KUBEADM_CONFIG_PATH} 
kubeadm init phase certs apiserver-kubelet-client --config ${KUBEADM_CONFIG_PATH}
kubeadm init phase certs front-proxy-client --config ${KUBEADM_CONFIG_PATH}
echo $(date "+%Y-%m-%d %H:%M:%S") "finish init certs"
# Write KubeConfig file to disk
echo $(date "+%Y-%m-%d %H:%M:%S") "start create kubeconfig"
kubeadm init phase kubeconfig all --config ${KUBEADM_CONFIG_PATH}
# Set Kubelet Args
# Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
# Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
# Restart the kubelet service 
echo $(date "+%Y-%m-%d %H:%M:%S") "set kubelet args"
kubeadm init phase kubelet-start --config ${KUBEADM_CONFIG_PATH}
# Write Static Pod manifest
echo $(date "+%Y-%m-%d %H:%M:%S") "write manifest"
kubeadm init phase control-plane all --config ${KUBEADM_CONFIG_PATH}

# Start Kubelet
echo $(date "+%Y-%m-%d %H:%M:%S") "restart kubelet"
systemctl daemon-reload
retry systemctl restart kubelet
is_systemd_active kubelet
echo $(date "+%Y-%m-%d %H:%M:%S") "finish restart kubelet"
echo $(date "+%Y-%m-%d %H:%M:%S") "wait for master started"
retry kubectl get nodes --kubeconfig /etc/kubernetes/admin.conf
echo $(date "+%Y-%m-%d %H:%M:%S") "master has been started"
echo $(date "+%Y-%m-%d %H:%M:%S") "create kubeconfig link"
ln -s /etc/kubernetes/admin.conf /root/.kube/config

if [ "${HOST_SID}" == "1" ]
then
    # storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
    echo $(date "+%Y-%m-%d %H:%M:%S") "upload kubeadm config"
    retry kubeadm init phase upload-config kubeadm --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    # Creating a ConfigMap "kubelet-config-1.13" in namespace kube-system with the configuration for the kubelets in the cluster
    echo $(date "+%Y-%m-%d %H:%M:%S") "upload kubelet config"
    retry kubeadm init phase upload-config kubelet --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    # Create Token
    echo $(date "+%Y-%m-%d %H:%M:%S") "Create Token"
    retry kubeadm init phase bootstrap-token --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    # Install Addons
    echo $(date "+%Y-%m-%d %H:%M:%S") "Install Kube-Proxy"
    retry install_kube_proxy
    # Install Network Plugin
    echo $(date "+%Y-%m-%d %H:%M:%S") "Install Network Plugin"
    retry install_network_plugin
    # Install Coredns
    echo $(date "+%Y-%m-%d %H:%M:%S") "Install Coredns"
    retry install_coredns
    # Install Storage Plugin
    echo $(date "+%Y-%m-%d %H:%M:%S") "Install CSI"
    retry install_csi
    # Install Tiller
    echo $(date "+%Y-%m-%d %H:%M:%S") "Install Tiller"
    retry install_tiller
fi

# Mark Master
echo $(date "+%Y-%m-%d %H:%M:%S") "Mark Master"
kubeadm init phase mark-control-plane --node-name ${HOST_INSTANCE_ID}

echo $(date "+%Y-%m-%d %H:%M:%S") "===end init master==="
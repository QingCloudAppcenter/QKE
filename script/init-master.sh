#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

link_dir
swapoff -a
systemctl restart docker
is_systemd_active docker

systemctl daemon-reload
retry systemctl start etcd
is_systemd_active etcd

replace_loadbalancer_ip

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
    scp /etc/kubernetes/control-plane-certificates.tar.gz root@${MASTER_2_INSTANCE_ID}:/etc/kubernetes
    scp /etc/kubernetes/control-plane-certificates.tar.gz root@${MASTER_3_INSTANCE_ID}:/etc/kubernetes
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

# Create access local apiserver file for kubeadm
cp /etc/kubernetes/admin.conf ${KUBE_LOCAL_CONF}
sed -i "s/${LOADBALANCER_IP}/${HOST_IP}/g" ${KUBE_LOCAL_CONF}

retry kubectl get nodes

if [ "${HOST_SID}" == "1" ]
then
    # Create a ConfigMap "kubelet-config-1.12" in namespace kube-system with the configuration for the kubelets in the cluster
    retry kubeadm alpha phase kubelet config upload --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBE_LOCAL_CONF}
    # storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
    retry kubeadm alpha phase upload-config --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBE_LOCAL_CONF}
    # Create Token
    retry kubeadm alpha phase bootstrap-token all --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBE_LOCAL_CONF}
fi

retry systemctl enable kubelet
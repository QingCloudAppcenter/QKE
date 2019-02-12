#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

link_dir

systemctl daemon-reload
retry systemctl start etcd
is_systemd_active etcd

systemctl restart docker
is_systemd_active docker

if [ "${HOST_SID}" == "1" ]
then
    retry kubeadm config images pull --config ${KUBEADM_CONFIG_PATH}
    kubeadm alpha phase certs all --config ${KUBEADM_CONFIG_PATH}

    kubeadm alpha phase kubeconfig all --config ${KUBEADM_CONFIG_PATH}
    kubeadm alpha phase kubelet config write-to-disk --config ${KUBEADM_CONFIG_PATH}
    kubeadm alpha phase kubelet write-env-file --config ${KUBEADM_CONFIG_PATH}
    kubeadm alpha phase controlplane all --config ${KUBEADM_CONFIG_PATH}

    systemctl daemon-reload
    retry systemctl start kubelet
    is_systemd_active kubelet

    cp /etc/kubernetes/admin.conf /root/.kube/config

    kubeadm alpha phase kubelet config upload --config ${KUBEADM_CONFIG_PATH}
    kubeadm alpha phase mark-master  --node-name ${HOST_INSTANCE_ID}
    # Create Token
    kubeadm alpha phase bootstrap-token all --config ${KUBEADM_CONFIG_PATH}
    # Install Network Plugin
    install_network_plugin
    # Install Addons
    kubeadm alpha phase addon all --config ${KUBEADM_CONFIG_PATH}

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
fi
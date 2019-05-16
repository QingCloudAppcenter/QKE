#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

echo "===start start client==="

source "${K8S_HOME}/script/common.sh"
export KUBECONFIG="/etc/kubernetes/admin.conf"

rm /root/.ssh/authorized_keys
ln -fs /data/authorized_keys /root/.ssh/authorized_keys

ensure_dir

swapoff -a

scp root@master1:/etc/kubernetes/admin.conf /root/.kube/config
cp /root/.kube/config /etc/kubernetes/admin.conf

#echo "Install KubeSphere"
#install_kubesphere
if [ ! -f "${CLIENT_INIT_LOCK}" ]; then
    echo "Install Cloud Controller Manager"
    install_cloud_controller_manager
    kubectl create ns kubesphere-system
    kubectl apply -f /opt/kubernetes/k8s/kubesphere/ks-console/ks-console-svc.yaml  
    touch ${CLIENT_INIT_LOCK}
fi



echo "===end start client==="
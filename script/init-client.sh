#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
source "${K8S_HOME}/script/loadbalancer-manager.sh"

echo "===start init client==="
link_dir
set_password
touch /etc/kubernetes/loadbalancer_ip
if [ ${ENV_MASTER_COUNT} -gt 1 ]
then
    create_lb_and_firewall ${CLUSTER_ID} ${CLUSTER_VXNET}
    ${K8S_HOME}/script/get-loadbalancer-ip.sh > /etc/kubernetes/loadbalancer_ip
    scp /etc/kubernetes/loadbalancer_ip root@master1:/etc/kubernetes
    scp /etc/kubernetes/loadbalancer_ip root@master2:/etc/kubernetes
    scp /etc/kubernetes/loadbalancer_ip root@master3:/etc/kubernetes

    replace_kubeadm_config_lb_ip
    replace_hosts_lb_ip
fi
if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    cat /etc/kubernetes/kubeadm-config.yaml
fi
echo "===end init client==="
#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
source "${K8S_HOME}/script/loadbalancer-manager.sh"

echo $(date "+%Y-%m-%d %H:%M:%S") "===start init client==="
echo $(date "+%Y-%m-%d %H:%M:%S") "link dir" 
link_dir
echo $(date "+%Y-%m-%d %H:%M:%S") "set password" 
set_password
echo $(date "+%Y-%m-%d %H:%M:%S") "make lb ip file" 
touch /etc/kubernetes/loadbalancer_ip
if [ ${ENV_MASTER_COUNT} -gt 1 ]
then
    echo $(date "+%Y-%m-%d %H:%M:%S") "ceate lb and firewall" 
    create_lb_and_firewall ${CLUSTER_ID} ${CLUSTER_VXNET}
    echo $(date "+%Y-%m-%d %H:%M:%S") "finish creating lb and firewall" 
    echo $(date "+%Y-%m-%d %H:%M:%S") "write lb ip" 
    ${K8S_HOME}/script/get-loadbalancer-ip.sh > /etc/kubernetes/loadbalancer_ip
    echo $(date "+%Y-%m-%d %H:%M:%S") "copy lb ip to HA masters" 
    scp /etc/kubernetes/loadbalancer_ip root@master1:/etc/kubernetes
    scp /etc/kubernetes/loadbalancer_ip root@master2:/etc/kubernetes
    scp /etc/kubernetes/loadbalancer_ip root@master3:/etc/kubernetes
    echo $(date "+%Y-%m-%d %H:%M:%S") "replace lb ip on kubeadm config" 
    replace_kubeadm_config_lb_ip
    echo $(date "+%Y-%m-%d %H:%M:%S") "replace lb ip on hosts" 
    replace_hosts_lb_ip
fi
if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    echo $(date "+%Y-%m-%d %H:%M:%S") "read kubeadm config" 
    cat /etc/kubernetes/kubeadm-config.yaml
fi
echo $(date "+%Y-%m-%d %H:%M:%S") "===end init client==="
#!/bin/bash
function RUN(){
    set -e
    swapoff -a

    SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
    K8S_HOME=$(dirname "${SCRIPTPATH}")

    source "${K8S_HOME}/script/common.sh"

    #ensure_dir
    
    kubeadm init --pod-network-cidr=192.168.0.0/16

    HOME=/root

    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config

    #apply network
    kubectl apply -f $HOME/CNI/calico/

    wait_kubelet  
    #wait_apiserver
}

logfile=/tmp/master_init.log
RUN >> $logfile 2>&1 


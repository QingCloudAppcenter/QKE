#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

if [ "${HOST_SID}" == "1" ]
then
    KUBEADM_TOKEN=$(kubeadm token list |grep forever | awk '{print $1}' | sed -n '1p')
    CA_CERT_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
    if [ "${MASTER_COUNT}" == "3" ]
    then
        printf "kubeadm join %s:6443 --token %s --discovery-token-ca-cert-hash sha256:%s" $(get_loadbalancer_ip) ${KUBEADM_TOKEN} ${CA_CERT_HASH}
    else
        printf "kubeadm join %s:6443 --token %s --discovery-token-ca-cert-hash sha256:%s" ${MASTER_1_IP} ${KUBEADM_TOKEN} ${CA_CERT_HASH}
else
    printf "Please print token in master 1"
fi
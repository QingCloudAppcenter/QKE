#!/usr/bin/env bash

# Copyright 2018 The KubeSphere Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

if [ "${HOST_SID}" == "1" ]
then
    KUBEADM_TOKEN=$(kubeadm token list |grep forever | awk '{print $1}' | sed -n '1p')
    CA_CERT_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
    if [ ${ENV_MASTER_COUNT} -eq 1 ]
    then
        printf "kubeadm join %s:6443 --token %s --discovery-token-ca-cert-hash sha256:%s --ignore-preflight-errors DirAvailable--etc-kubernetes-manifests" ${MASTER_1_IP} ${KUBEADM_TOKEN} ${CA_CERT_HASH}
    elif [ ${ENV_MASTER_COUNT} -gt 1 ]
    then
        printf "kubeadm join %s:6443 --token %s --discovery-token-ca-cert-hash sha256:%s --ignore-preflight-errors DirAvailable--etc-kubernetes-manifests" $(get_loadbalancer_ip) ${KUBEADM_TOKEN} ${CA_CERT_HASH}
    else
        echo "value error: ENV_MASTER_COUNT=[${ENV_MASTER_COUNT}]"
        exit -1
    fi
else
    printf "Please print token in master 1"
fi
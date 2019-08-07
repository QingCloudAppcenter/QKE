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

CERT_FILES=(
    "/data/kubernetes/pki/apiserver-kubelet-client.crt"
    "/data/kubernetes/pki/apiserver.crt"
    "/data/kubernetes/pki/front-proxy-client.crt"
    )

CERT_SUB_CMD=(
    "apiserver-kubelet-client"
    "apiserver"
    "front-proxy-client"
)

ONE_MONTH_TIMESTAMP=2592000

function is_needed_renew_cert(){
    filename=$1
    expire_date=$(openssl x509 -in ${filename} -noout -enddate  | sed "s/notAfter=//g")
    expire_ts=$(date -d "${expire_date}" +%s)
    current_ts=$(date '+%s')
    difference_ts=$(expr $expire_ts - $current_ts)
    if [ ${difference_ts} -lt ${ONE_MONTH_TIMESTAMP} ]
    then
        return 0
    else
        return 1
    fi
}

function renew_cert_files(){
    for i in "${!CERT_FILES[@]}"
    do
        if [ ! -f ${CERT_FILES[$i]} ]
        then
            kubeadm alpha certs renew ${CERT_SUB_CMD[$i]} --config ${KUBEADM_CONFIG_PATH}
        fi
        is_needed_renew_cert ${CERT_FILES[$i]}
        if [ $? -eq 0 ]
        then
            kubeadm alpha certs renew ${CERT_SUB_CMD[$i]} --config ${KUBEADM_CONFIG_PATH}
        fi
    done
}

if [ "${HOST_ROLE}" == "master" ]
then
    renew_cert_files
    restart_kubernetes_control_plane
fi
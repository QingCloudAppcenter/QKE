#!/usr/bin/env bash

# Copyright 2019 The KubeSphere Authors.
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

if [ ${ENV_MASTER_COUNT} -gt 1 ]
then
    replace_kubeadm_eip_lb_ip
fi

if [ "${HOST_ROLE}" == "master" ]
then
    log "remove apiserver.crt"
    rm -rf /etc/kubernetes/pki/apiserver.crt
    log "remove apiserver.key"
    rm -rf /etc/kubernetes/pki/apiserver.key
    log "create apiserver certs with eip"
    kubeadm init phase certs apiserver --config ${KUBEADM_EIP_PATH}
    log "restart kubernetes apiserver"
    kill -9 $(pidof kube-apiserver)
fi
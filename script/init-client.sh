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
${K8S_HOME}/script/check-fs.sh
${K8S_HOME}/script/check-env.sh
touch /etc/kubernetes/loadbalancer_ip
source "${K8S_HOME}/script/common.sh"
source "${K8S_HOME}/script/loadbalancer-manager.sh"

log "===start init client==="
log "make lb ip file" 

log "link dir" 
link_dir
log "set password" 
set_password

if [ ${ENV_MASTER_COUNT} -gt 1 ]
then
    log "ceate lb and firewall" 
    create_lb_and_firewall ${CLUSTER_ID} ${CLUSTER_VXNET}
    log "finish creating lb and firewall" 
    log "write lb ip" 
    ${K8S_HOME}/script/get-loadbalancer-ip.sh > /etc/kubernetes/loadbalancer_ip
    log "copy lb ip to HA masters" 
    for((i=1;i<=${ENV_MASTER_COUNT};i++));
    do
        scp /etc/kubernetes/loadbalancer_ip root@master${i}:/etc/kubernetes
    done
    log "replace lb ip on kubeadm config" 
    replace_kubeadm_config_lb_ip
    log "replace kubeadm eip lb ip"
    replace_kubeadm_eip_lb_ip
    log "replace lb ip on hosts" 
    replace_hosts_lb_ip
fi
if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    log "read kubeadm config" 
    cat /etc/kubernetes/kubeadm-config.yaml
fi

touch ${PERMIT_RELOAD_LOCK}
chmod 400 ${PERMIT_RELOAD_LOCK}
log "===end init client==="
exit 0
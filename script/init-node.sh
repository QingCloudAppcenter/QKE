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
source "${K8S_HOME}/script/common.sh"
log "===start init node==="
log "link dir"
link_dir
log "swapoff"
swapoff -a
log "touch lb file"
touch /etc/kubernetes/loadbalancer_ip
log "restart docker"
systemctl restart docker
is_systemd_active docker
log "finish restart docker"

if [ -f "${KUBEADM_CONFIG_PATH}" ]
then
    log "read kubeadm config"
    cat ${KUBEADM_CONFIG_PATH}
fi

touch ${PERMIT_RELOAD_LOCK}
chmod 400 ${PERMIT_RELOAD_LOCK}
log "===end init node==="
exit 0
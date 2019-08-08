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
source "${K8S_HOME}/script/common.sh"
log "===start start node==="
log "swapoff"
swapoff -a
log "ensure dir"
ensure_dir

# Start Docker
log "start docker"
retry systemctl restart docker
is_systemd_active docker
log "finish starting docker"

log "join node"
join_node
log "finish joining node"

# Write kubelet configuration to file "/var/lib/kubelet/config.yaml"
# Write kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
log "write kubelet config"
kubeadm init phase kubelet-start --config  ${KUBEADM_CONFIG_PATH}
log "finish writing kubelet config"

# Reload config
log "daemon reload"
systemctl daemon-reload

# Start Kubelet
log "restart kubelet"
retry systemctl start kubelet
is_systemd_active kubelet

if [ -f "/etc/kubernetes/kubeadm-config.yaml" ]
then
    log "cat kubeadm config"
    cat /etc/kubernetes/kubeadm-config.yaml
fi
log "===end start node==="
exit 0
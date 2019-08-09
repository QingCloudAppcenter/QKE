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
log "===start scale in==="

retry kubectl get nodes --kubeconfig ${KUBECONFIG}
for node in $(cat "/opt/kubernetes/k8s/kubernetes/scale-in.info")
do
    n=$(echo $node|tr '\n' ' ')
    if [ "$n" != "" ]
    then
        log "drain node" ${n}
        drain_node ${n}
        log "drain node result" $?
        log "kubectl delete node" ${n}
        kubectl delete node/${n} --kubeconfig ${KUBECONFIG}
        log "delete node result" $?
    fi
done
log "===end scale in==="
exit 0


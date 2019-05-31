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

KS_CONSOLE_SVC_CONTENT=$(kubectl get svc -n kubesphere-system ks-console -o=json)
if [ "${KS_CONSOLE_SVC_CONTENT}" == "" ]
then
    echo "Cannot get ks console service"
    exit
fi

KS_CONSOLE_SVC_TYPE=$(echo ${KS_CONSOLE_SVC_CONTENT} | jq .spec.type | sed 's/\"//g')

case $KS_CONSOLE_SVC_TYPE in
"LoadBalancer")
    echo http://$(echo ${KS_CONSOLE_SVC_CONTENT} | jq '.status.loadBalancer.ingress[0].ip'| sed 's/\"//g'):30880
    ;;
"NodePort")
    echo http://${MASTER_1_IP}:$(echo ${KS_CONSOLE_SVC_CONTENT}  | jq '.spec.ports[0].nodePort')
    ;;
*)
    echo "Invalid Service Type"
    exit
    ;;
esac
#!/usr/bin/env bash

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

kubelet_ready="false"
docker_ready="false"
if systemctl is-active docker
then
  docker_ready="true"
fi
if systemctl is-active kubelet
then
    status=$(get_node_status)
    echo "ready:${status}"
    if [ "${status}" == "True" ]
    then
        kubelet_ready="true"
    fi
fi

if [ "${docker_ready}" == "true" ] && [ "${kubelet_ready}" == "true" ]
then
  exit 0
else
  exit 1
fi
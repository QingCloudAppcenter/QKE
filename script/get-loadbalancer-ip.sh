#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
source "${K8S_HOME}/script/loadbalancer-manager.sh"

LB_ID=$(get_loadbalancer_id "${CLUSTER_ID}")
if [ "${LB_ID}" != "" ]
then
    get_loadbalancer_ip ${LB_ID}
fi
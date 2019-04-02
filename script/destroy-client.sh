#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
source "${K8S_HOME}/script/loadbalancer-manager.sh"

if [ "${MASTER_COUNT}" == "3" ]
then
    delete_lb_and_firewall ${CLUSTER_ID}
fi
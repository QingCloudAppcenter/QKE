#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

if [ "${HOST_ROLE}" == "master" ]
then
    kubectl delete -f /opt/kubernetes/k8s/kubesphere/ks-console/ks-console-svc.yaml
fi
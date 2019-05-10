#!/usr/bin/env bash
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
    echo http://$(echo ${KS_CONSOLE_SVC_CONTENT} | jq '.status.loadBalancer.ingress[0].ip'| sed 's/\"//g'):80
    ;;
"NodePort")
    echo http://${MASTER_1_IP}:$(echo ${KS_CONSOLE_SVC_CONTENT}  | jq '.spec.ports[0].nodePort')
    ;;
*)
    echo "Invalid Service Type"
    exit
    ;;
esac
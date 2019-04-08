#!/usr/bin/env bash

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

echo "===start scale in==="

retry kubectl get nodes --kubeconfig /etc/kubernetes/admin.conf
for node in $(cat "/etc/kubernetes/scale_in.info")
do
    n=$(echo $node|tr '\n' ' ')
    if [ "$n" != "" ]
    then
        drain_node ${n}
        kubectl delete node/${n} --kubeconfig /etc/kubernetes/admin.conf
    fi
done
echo "===end scale in==="
exit 0


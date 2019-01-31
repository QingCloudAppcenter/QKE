#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

systemctl stop kubelet
docker_stop_rm_all
docker_stop

# stop etcd
systemctl start etcd
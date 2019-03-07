#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

link_dir
set_password

retry scp root@master1:/etc/kubernetes/admin.conf /root/.kube/config
cp /root/.kube/config /etc/kubernetes/admin.conf
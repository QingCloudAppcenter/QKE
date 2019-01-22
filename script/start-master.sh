#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname $(dirname $(dirname "${SCRIPTPATH}")))

source "${K8S_HOME}/scripts/ha/runtime/common.sh"

swapoff -a
rm /root/.ssh/authorized_keys
ln -fs /data/authorized_keys /root/.ssh/authorized_keys

systemctl start etcd
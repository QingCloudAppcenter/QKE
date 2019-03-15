#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"
export KUBECONFIG="/etc/kubernetes/admin.conf"

rm /root/.ssh/authorized_keys
ln -fs /data/authorized_keys /root/.ssh/authorized_keys

ensure_dir

swapoff -a
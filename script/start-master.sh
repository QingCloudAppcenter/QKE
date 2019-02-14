#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

swapoff -a
link_dir

# Reload config
systemctl daemon-reload

# Start etcd
retry systemctl start etcd
is_systemd_active etcd

# Start Docker
retry systemctl restart docker
is_systemd_active docker

# Start Kubelet
retry systemctl start kubelet
is_systemd_active kubelet



#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

link_dir
swapoff -a

systemctl restart docker
is_systemd_active docker

replace_loadbalancer_ip
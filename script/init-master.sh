#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

link_dir

# Start etcd
systemctl daemon-reload
retry systemctl start etcd
is_systemd_active etcd
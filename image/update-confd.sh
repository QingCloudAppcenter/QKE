#!/usr/bin/env bash

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

echo "*************************"
echo "update confd"
echo "*************************"

rm -rf /etc/confd/conf.d/k8s
rm -rf /etc/confd/templates/k8s
mkdir -p /etc/confd
cp -r ${K8S_HOME}/confd/* /etc/confd/

if systemctl is-active confd > /dev/null
then
    systemctl restart confd
fi

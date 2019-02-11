#!/usr/bin/env bash

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

echo "*************************"
echo "update cni"
echo "*************************"

source ${K8S_HOME}/version

CNI_VERSION=v0.6.0
CNI_PLUGINS_VERSION=v0.7.1

pushd /tmp
wget -c https://pek3a.qingstor.com/k8s-qingcloud/k8s/tool/cni-amd64-${CNI_VERSION}.tgz
wget -c https://pek3a.qingstor.com/k8s-qingcloud/k8s/tool/cni-plugins-amd64-${CNI_PLUGINS_VERSION}.tgz
mkdir -p /opt/cni/bin
tar -zxvf cni-amd64-${CNI_VERSION}.tgz -C /opt/cni/bin
tar -zxvf cni-plugins-amd64-${CNI_PLUGINS_VERSION}.tgz -C /opt/cni/bin
rm cni*.tgz

popd

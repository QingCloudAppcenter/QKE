#!/usr/bin/env bash

echo "*************************"
echo "install kubernetes binary files [kubeadm, kubelet, kubectl]"
echo "*************************"

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname $(dirname "${SCRIPTPATH}"))

source ${K8S_HOME}/version

KUBE_BIN_VER=$(echo $HYPERKUBE_VERSION|sed  's/^v//g')-00
apt-get update && apt-get install -y apt-transport-https curl

echo KUBE_BIN_VER = ${KUBE_BIN_VER}

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update

apt-get install -y kubelet=${KUBE_BIN_VER} kubeadm=${KUBE_BIN_VER} kubectl=${KUBE_BIN_VER}

apt-mark hold kubelet kubeadm kubectl
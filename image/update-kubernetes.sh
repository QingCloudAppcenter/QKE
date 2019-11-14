#!/usr/bin/env bash

# Copyright 2018 The KubeSphere Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

echo "*************************"
echo "update kubernetes binary files [kubeadm, kubelet, kubectl]"
echo "*************************"

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source ${K8S_HOME}/version

KUBE_BIN_VER=$(echo $HYPERKUBE_VERSION|sed  's/^v//g')-00
echo KUBE_BIN_VER = ${KUBE_BIN_VER}
apt-get update && apt-get install -y apt-transport-https curl

# We cannot reach the Kubernetes official site and use ali mirror instead.
# curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
# cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
# deb https://apt.kubernetes.io/ kubernetes-xenial main
# EOF

curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

apt-get update

apt-get install -y kubelet=${KUBE_BIN_VER} kubeadm=${KUBE_BIN_VER} kubectl=${KUBE_BIN_VER}

apt-mark hold kubelet kubeadm kubectl

# Autocompletion
source /usr/share/bash-completion/bash_completion >> ~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash >/etc/bash_completion.d/kubectl

systemctl daemon-reload
systemctl stop kubelet
systemctl disable kubelet

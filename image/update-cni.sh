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

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

echo "*************************"
echo "update cni"
echo "*************************"

source ${K8S_HOME}/version

# install cni through apt
apt install kubernetes-cni=0.7.5-00

CNI_VERSION=v0.6.0

pushd /tmp
wget -c https://pek3a.qingstor.com/k8s-qingcloud/k8s/tool/cni-amd64-${CNI_VERSION}.tgz
mkdir -p /opt/cni/bin
tar -zxvf cni-amd64-${CNI_VERSION}.tgz -C /opt/cni/bin
rm cni*.tgz

popd

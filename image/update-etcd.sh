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
echo "update etcd"
echo "*************************"

ETCD_VERSION=v3.2.24

pushd /tmp
wget -c https://pek3a.qingstor.com/k8s-qingcloud/k8s/etcd/v3.2.24/etcd-${ETCD_VERSION}-linux-amd64.tar.gz
tar -zxvf etcd-${ETCD_VERSION}-linux-amd64.tar.gz
cp etcd-v3.2.24-linux-amd64/etcd /usr/bin
cp etcd-v3.2.24-linux-amd64/etcdctl /usr/bin
rm etcd-*-linux-amd64.tar.gz
rm -rf etcd-v3.2.24-linux-amd64

mkdir -p /var/lib/etcd
popd
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
echo "update docker images"
echo "*************************"

systemctl start docker

docker pull gcr.azk8s.cn/google-containers/hyperkube:v1.15.5
docker pull gcr.azk8s.cn/google-containers/pause:3.1

# Network
docker pull gcr.azk8s.cn/google_containers/coredns:1.3.1
docker pull gcr.azk8s.cn/google_containers/coredns:1.3.1
docker pull calico/node:v3.8.4
docker pull calico/cni:v3.8.4
docker pull calico/kube-controllers:v3.8.4
docker pull calico/pod2daemon-flexvol:v3.8.4
docker pull quay.io/coreos/flannel:v0.11.0-amd64
docker pull kubesphere/cloud-controller-manager:v1.4.2

# Storage
docker pull quay.io/k8scsi/csi-provisioner:v1.4.0
docker pull quay.io/k8scsi/csi-attacher:v2.0.0
docker pull quay.io/k8scsi/csi-snapshotter:v1.2.2
docker pull quay.io/k8scsi/csi-resizer:v0.2.0
docker pull csiplugin/csi-qingcloud:v1.1.0
docker pull quay.io/k8scsi/csi-node-driver-registrar:v1.2.0

# tiller
docker pull gcr.azk8s.cn/kubernetes-helm/tiller:v2.12.3

systemctl stop docker
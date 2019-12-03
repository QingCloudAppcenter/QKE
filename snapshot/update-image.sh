#!/usr/bin/env bash

# Copyright 2019 The KubeSphere Authors.
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

SNAPSHOT_DIR="/upgrade"

docker save gcr.azk8s.cn/google-containers/hyperkube:v1.15.5 > ${SNAPSHOT_DIR}/hyperkube-v1.15.5.img
docker save gcr.azk8s.cn/google-containers/pause:3.1 > ${SNAPSHOT_DIR}/pause-3.1.img

# Network
docker save gcr.azk8s.cn/google_containers/coredns:1.3.1 > ${SNAPSHOT_DIR}/coredns-1.3.1.img
docker save calico/node:v3.8.4 > ${SNAPSHOT_DIR}/calico-node-v3.8.4.img
docker save calico/cni:v3.8.4 > ${SNAPSHOT_DIR}/calico-cni-v3.8.4.img
docker save calico/kube-controllers:v3.8.4 > ${SNAPSHOT_DIR}/calico-kube-controllers-v3.8.4.img
docker save calico/pod2daemon-flexvol:v3.8.4 > ${SNAPSHOT_DIR}/calico-pod2daemon-flexvol-v3.8.4.img
docker save quay.io/coreos/flannel:v0.11.0-amd64 > ${SNAPSHOT_DIR}/flannel-v0.11.0-amd64.img
docker save kubesphere/cloud-controller-manager:v1.4.2 > ${SNAPSHOT_DIR}/cloud-controller-manager-v1.4.2.img

# Storage
docker save quay.io/k8scsi/csi-provisioner:v1.4.0 > ${SNAPSHOT_DIR}/csi-provisioner-v1.4.0.img
docker save quay.io/k8scsi/csi-attacher:v2.0.0 > ${SNAPSHOT_DIR}/csi-attacher-v2.0.0.img
docker save quay.io/k8scsi/csi-snapshotter:v1.2.2 > ${SNAPSHOT_DIR}/csi-snapshotter-v1.2.2.img
docker save quay.io/k8scsi/csi-resizer:v0.2.0 > ${SNAPSHOT_DIR}/csi-resizer-v0.2.0.img
docker save csiplugin/csi-qingcloud:v1.1.0 > ${SNAPSHOT_DIR}/csi-qingcloud-v1.1.0.img
docker save quay.io/k8scsi/csi-node-driver-registrar:v1.2.0 > ${SNAPSHOT_DIR}/csi-node-driver-registrar-v1.2.0.img

# tiller
docker save gcr.azk8s.cn/kubernetes-helm/tiller:v2.12.3 > ${SNAPSHOT_DIR}/tiller-v2.12.3.img
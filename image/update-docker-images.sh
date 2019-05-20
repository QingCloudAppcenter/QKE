#!/usr/bin/env bash

echo "*************************"
echo "update docker images"
echo "*************************"


docker login -u guest -p guest dockerhub.qingcloud.com

# Basic
docker pull dockerhub.qingcloud.com/google_containers/hyperkube:v1.13.5
docker pull dockerhub.qingcloud.com/google_containers/pause:3.1

# Network
docker pull dockerhub.qingcloud.com/google_containers/coredns:1.2.6
docker pull dockerhub.qingcloud.com/calico/typha:v3.3.6
docker pull dockerhub.qingcloud.com/calico/node:v3.3.6
docker pull dockerhub.qingcloud.com/calico/cni:v3.3.6
docker pull dockerhub.qingcloud.com/calico/kube-controllers:v3.1.3
docker pull dockerhub.qingcloud.com/coreos/flannel:v0.11.0-amd64
docker pull kubespheredev/cloud-controller-manager:v1.3.4

# QingCloud CSI
docker pull dockerhub.qingcloud.com/k8scsi/csi-provisioner:v0.2.1
docker pull dockerhub.qingcloud.com/k8scsi/csi-attacher:v0.2.0
docker pull dockerhub.qingcloud.com/k8scsi/driver-registrar:v0.2.0
docker pull dockerhub.qingcloud.com/csiplugin/csi-qingcloud:v0.2.1



# KubeSphere                    
docker pull dockerhub.qingcloud.com/kubernetes_helm/tiller:v2.11.0
docker pull nginx
docker pull busybox

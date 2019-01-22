#!/usr/bin/env bash

echo "*************************"
echo "update docker images"
echo "*************************"

docker pull gcr.io/google_containers/hyperkube-amd64:v1.12.4
docker pull k8s.gcr.io/pause:3.1
docker pull k8s.gcr.io/coredns:1.2.2     
docker pull quay.io/calico/node:v3.3.2
docker pull quay.io/calico/cni:v3.3.2
docker pull k8s.gcr.io/etcd:3.2.24
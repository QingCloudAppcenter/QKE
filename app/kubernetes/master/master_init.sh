#!/bin/bash

kubeadm init --pod-network-cidr=192.168.0.0/16


mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

#apply network
kubectl apply -f CNI/calico/
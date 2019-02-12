#!/usr/bin/env bash

echo "*************************"
echo "update systemd"
echo "*************************"

systemctl daemon-reload
systemctl disable kubelet
systemctl stop kubelet
systemctl disable docker
systemctl stop docker
systemctl disable etcd
systemctl stop etcd
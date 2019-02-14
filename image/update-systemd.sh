#!/usr/bin/env bash

echo "*************************"
echo "update systemd"
echo "*************************"

systemctl daemon-reload

systemctl stop kubelet
systemctl stop docker

systemctl disable kubelet
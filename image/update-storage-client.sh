#!/usr/bin/env bash

echo "*************************"
echo "update storage client"
echo "*************************"

apt install nfs-common -y
apt install ceph-common -y

add-apt-repository -y ppa:gluster/glusterfs-3.12
apt-get update
apt-get install glusterfs-client -y
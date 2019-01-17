#!/usr/bin/env bash

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
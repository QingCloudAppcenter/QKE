#!/bin/bash

swapoff -a
sysctl net.bridge.bridge-nf-call-iptables=1

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

## Download GPG key.
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
## Add docker apt repository.
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common

apt-get install -y kubelet kubeadm kubectl docker.io
apt-mark hold kubelet kubeadm kubectl

## Install docker ce.
#apt-get install docker-ce=18.06.0~ce~3-0~ubuntu

# Setup daemon.
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker


##pull image
kubeadm config images list
kubeadm config images pull

##pull CNI image
mkdir -p CNI/flannel
wget https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml -O CNI/flannel/kube-flannel.yml
docker pull quay.io/coreos/flannel:v0.10.0-amd64

mkdir -p CNI/calico
wget https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml -O CNI/calico/rbac-kdd.yaml
wget https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml -O CNI/calico/calico.yaml
docker pull quay.io/calico/typha:v3.3.2
docker pull quay.io/calico/node:v3.3.2
docker pull quay.io/calico/cni:v3.3.2

##install agent
echo "install agent"
wget -qO- http://appcenter-docs.qingcloud.com/developer-guide/scripts/app-agent-linux-amd64.tar.gz | tar -xvz
cd app-agent-linux-amd64
./install.sh
cd ../
rm -rf app-agent-linux-amd64
echo "DONE"

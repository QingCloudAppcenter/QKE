
# Upgrading kubeadm clusters from v1.13 to v1.14
https://v1-15.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade-1-14/

## source
```
curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
```

## First master
```
apt-mark unhold kubeadm kubelet && \
apt-get update && apt-get install -y kubeadm=1.14.4-00 && \
apt-mark hold kubeadm

kubeadm version

sudo kubeadm upgrade plan

sudo kubeadm upgrade apply v1.14.4

apt-mark unhold kubelet kubectl && \
apt-get update && apt-get install -y kubelet=1.15.4-00 kubectl=1.15.4-00 && \
apt-mark hold kubelet kubectl

sudo systemctl restart kubelet
```

## Other control plane
Same as the first control plane node but use:
```
sudo kubeadm upgrade node experimental-control-plane
```
instead of:
```
kubeadm upgrade apply
```

## Worker nodes
```
apt-mark unhold kubeadm kubelet && \
apt-get update && apt-get install -y kubeadm=1.15.4-00 && \
apt-mark hold kubeadm

kubectl drain $NODE --ignore-daemonsets

sudo kubeadm upgrade node config --kubelet-version v1.15.4

apt-mark unhold kubelet kubectl && \
apt-get update && apt-get install -y kubelet=1.15.4-00 kubectl=1.15.4-00 && \
apt-mark hold kubelet kubectl

sudo systemctl restart kubelet

kubectl uncordon $NODE
```

# Docker
```
docker pull gcr.azk8s.cn/google-containers/hyperkube:v1.14.4
docker pull gcr.azk8s.cn/google-containers/pause:3.1
```
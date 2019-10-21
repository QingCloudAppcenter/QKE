# How to install Kubernetes v1.15.5

## Set network

## Install Docker
```
apt-get update

apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common -y

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

apt-get update

apt-get install docker-ce=18.06.2~ce~3-0~ubuntu -y

docker info

apt-mark hold docker-ce

systemctl stop docker
```

## Install Kubernetes binary
```
swapoff
KUBE_BIN_VER=1.15.5-00
apt-get update && apt-get install -y apt-transport-https curl

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update
apt-get install -y kubelet=${KUBE_BIN_VER} kubectl=${KUBE_BIN_VER} kubeadm=${KUBE_BIN_VER}

apt-mark hold kubelet kubeadm kubectl

# Autocompletion
source /usr/share/bash-completion/bash_completion >> ~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash >/etc/bash_completion.d/kubectl

systemctl daemon-reload
systemctl stop kubelet
systemctl disable kubelet
```

## Init master

```
vi kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: v1.15.5
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/16
  podSubnet: 10.10.0.0/16
scheduler: {}
```

```
kubeadm init --config kubeadm-config.yaml
```

### Init phase

## Install Network Plugin
### Calico

```
wget https://docs.projectcalico.org/v3.8/manifests/calico.yaml
```

> Set Line 256 as Pod Id

```
621             # The default IPv4 pool to create on startup if none exists. Pod IPs will be
622             # chosen from this range. Changing this value after installation will have
623             # no effect. This should fall within `--cluster-cidr`.
624             - name: CALICO_IPV4POOL_CIDR
625               value: "10.10.0.0/16"
626             # Disable file logging so `kubectl logs` works.
```

```
kubectl create -f calico.yaml
```

### Flannel

```
wget https://raw.githubusercontent.com/coreos/flannel/62e44c867a2846fefb68bd5f178daf4da3095ccb/Documentation/kube-flannel.yml
```

> Set Line 127 as Pod IP

```
125   net-conf.json: |
126     {
127       "Network": "10.10.0.0/16",
128       "Backend": {
129         "Type": "vxlan"
130       }
131     }
132 ---
```

```
kubectl create -f kube-flannel.yaml
```
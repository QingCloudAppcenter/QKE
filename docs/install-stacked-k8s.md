# How to install stacked control plane Kubernetes

> https://v1-12.docs.kubernetes.io/docs/setup/independent/high-availability/#stacked-control-plane-nodes

## Prepare

### Docker

Please install [specific version of Docker](install-specific-ver-docker.md). Docker version no more than 18.06.

### Kubeadm

Please install [specific version of Kubeadm and Kubelet](install-specfic-ver-kubeadm.md).

### LB

- Create LB in QingCloud console
- Add TCP port forwarding rule: 6443 to 6443 
- Add firewall rules

## Install Control Plane

### First control plane

#### Edit config file

```
$ swapoff -a
```

```
export LB_IP=192.168.1.251
export LB_NAME=apiserver-lb
export CP0_IP=192.168.1.20
export CP0_HOSTNAME=$(hostname)
```

```
$ cat << EOF > ~/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1alpha3
kind: InitConfiguration
bootstrapTokens:
- ttl: "0"
nodeRegistration:
  kubeletExtraArgs:
    cgroup-driver: "cgroupfs"
    max-pods: "60"
    fail-swap-on: "true"
---
apiVersion: kubeadm.k8s.io/v1alpha3
kind: ClusterConfiguration
etcd:
  local:
    extraArgs:
      name: "${CP0_HOSTNAME}"
      listen-client-urls: "https://127.0.0.1:2379,https://${CP0_IP}:2379"
      advertise-client-urls: "https://${CP0_IP}:2379"
      listen-peer-urls: "https://${CP0_IP}:2380"
      initial-advertise-peer-urls: "https://${CP0_IP}:2380"
      initial-cluster: "${CP0_HOSTNAME}=https://${CP0_IP}:2380"
    serverCertSANs:
      - ${CP0_HOSTNAME}
      - ${CP0_IP}
    peerCertSANs:
      - ${CP0_HOSTNAME}
      - ${CP0_IP}
networking:
  dnsDomain: cluster.local
  podSubnet: 10.10.0.0/16
  serviceSubnet: 10.96.0.0/16
kubernetesVersion: "v1.12.4"
controlPlaneEndpoint: "${LB_IP}:6443"
apiServerCertSANs:
- "${LB_NAME}"
imageRepository: "k8s.gcr.io"
unifiedControlPlaneImage: "gcr.io/google_containers/hyperkube-amd64:v1.12.4"
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
EOF
```

#### Install

```
kubeadm init --config kubeadm-config.yaml
...
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes master has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join 192.168.1.251:6443 --token ayq6f1.mk97yupvon67kgdq --discovery-token-ca-cert-hash sha256:0246fa9f804ff9d68134da8c2e43f63a6bb6a8dc586fac8e5bab6d94f04e679b

```

#### Copy Cert files

```
export CP1_IP=192.168.1.21
export CP2_IP=192.168.1.22
```

```
USER=ubuntu 
CONTROL_PLANE_IPS="${CP1_IP} ${CP2_IP}"
for host in ${CONTROL_PLANE_IPS}; do
    scp /etc/kubernetes/pki/ca.crt "${USER}"@$host:
    scp /etc/kubernetes/pki/ca.key "${USER}"@$host:
    scp /etc/kubernetes/pki/sa.key "${USER}"@$host:
    scp /etc/kubernetes/pki/sa.pub "${USER}"@$host:
    scp /etc/kubernetes/pki/front-proxy-ca.crt "${USER}"@$host:
    scp /etc/kubernetes/pki/front-proxy-ca.key "${USER}"@$host:
    scp /etc/kubernetes/pki/etcd/ca.crt "${USER}"@$host:etcd-ca.crt
    scp /etc/kubernetes/pki/etcd/ca.key "${USER}"@$host:etcd-ca.key
    scp /etc/kubernetes/admin.conf "${USER}"@$host:
done
```

### Second control plane

```
swapoff -a
```

#### Edit config file

```
export LB_IP=192.168.1.251
export LB_NAME=apiserver-lb
export CP0_IP=192.168.1.20
export CP0_HOSTNAME=i-xwa1hzr9
export CP1_IP=192.168.1.21
export CP1_HOSTNAME=$(hostname)
```

```
$ cat << EOF > ~/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1alpha3
kind: InitConfiguration
bootstrapTokens:
- ttl: "0"
nodeRegistration:
  kubeletExtraArgs:
    cgroup-driver: "cgroupfs"
    max-pods: "60"
    fail-swap-on: "true"
---
apiVersion: kubeadm.k8s.io/v1alpha3
kind: ClusterConfiguration
etcd:
  local:
    extraArgs:
      name: "${CP1_HOSTNAME}"
      listen-client-urls: "https://127.0.0.1:2379,https://${CP1_IP}:2379"
      advertise-client-urls: "https://${CP1_IP}:2379"
      listen-peer-urls: "https://${CP1_IP}:2380"
      initial-advertise-peer-urls: "https://${CP1_IP}:2380"
      initial-cluster: "${CP0_HOSTNAME}=https://${CP0_IP}:2380,${CP1_HOSTNAME}=https://${CP1_IP}:2380"
      initial-cluster-state: existing
    serverCertSANs:
      - ${CP1_HOSTNAME}
      - ${CP1_IP}
    peerCertSANs:
      - ${CP1_HOSTNAME}
      - ${CP1_IP}
networking:
  dnsDomain: cluster.local
  podSubnet: 10.10.0.0/16
  serviceSubnet: 10.96.0.0/16
kubernetesVersion: "v1.12.4"
controlPlaneEndpoint: "${LB_IP}:6443"
apiServerCertSANs:
- "${LB_NAME}"
imageRepository: "k8s.gcr.io"
unifiedControlPlaneImage: "gcr.io/google_containers/hyperkube-amd64:v1.12.4"
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
EOF
```

#### Move cert files

```
USER=ubuntu # customizable
mkdir -p /etc/kubernetes/pki/etcd
mv /home/${USER}/ca.crt /etc/kubernetes/pki/
mv /home/${USER}/ca.key /etc/kubernetes/pki/
mv /home/${USER}/sa.pub /etc/kubernetes/pki/
mv /home/${USER}/sa.key /etc/kubernetes/pki/
mv /home/${USER}/front-proxy-ca.crt /etc/kubernetes/pki/
mv /home/${USER}/front-proxy-ca.key /etc/kubernetes/pki/
mv /home/${USER}/etcd-ca.crt /etc/kubernetes/pki/etcd/ca.crt
mv /home/${USER}/etcd-ca.key /etc/kubernetes/pki/etcd/ca.key
mv /home/${USER}/admin.conf /etc/kubernetes/admin.conf
```

#### Run kubeadm phase commands

```
kubeadm alpha phase certs all --config kubeadm-config.yaml
kubeadm alpha phase kubelet config write-to-disk --config kubeadm-config.yaml
kubeadm alpha phase kubelet write-env-file --config kubeadm-config.yaml
kubeadm alpha phase kubeconfig kubelet --config kubeadm-config.yaml
systemctl start kubelet
```

#### Add Etcd

```
kubeadm alpha phase etcd local --config kubeadm-config.yaml
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl exec -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add ${CP1_HOSTNAME} https://${CP1_IP}:2380
```

#### Deploy control plane

> WAIT 
```
kubeadm alpha phase kubeconfig all --config kubeadm-config.yaml
kubeadm alpha phase controlplane all --config kubeadm-config.yaml
kubeadm alpha phase kubelet config annotate-cri --config kubeadm-config.yaml
kubeadm alpha phase mark-master --config kubeadm-config.yaml
```

### Third control plane

```
swapoff -a
```

#### Edit config file

```
export LB_IP=192.168.1.251
export LB_NAME=apiserver-lb
export CP0_IP=192.168.1.20
export CP0_HOSTNAME=i-xwa1hzr9
export CP1_IP=192.168.1.21
export CP1_HOSTNAME=i-vrbvckx2
export CP2_IP=192.168.1.22
export CP2_HOSTNAME=$(hostname)
```

```
$ cat << EOF > ~/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1alpha3
kind: InitConfiguration
bootstrapTokens:
- ttl: "0"
nodeRegistration:
  kubeletExtraArgs:
    cgroup-driver: "cgroupfs"
    max-pods: "60"
    fail-swap-on: "true"
---
apiVersion: kubeadm.k8s.io/v1alpha3
kind: ClusterConfiguration
etcd:
  local:
    extraArgs:
      name: "${CP2_HOSTNAME}"
      listen-client-urls: "https://127.0.0.1:2379,https://${CP2_IP}:2379"
      advertise-client-urls: "https://${CP2_IP}:2379"
      listen-peer-urls: "https://${CP2_IP}:2380"
      initial-advertise-peer-urls: "https://${CP2_IP}:2380"
      initial-cluster: "${CP0_HOSTNAME}=https://${CP0_IP}:2380,${CP1_HOSTNAME}=https://${CP1_IP}:2380,${CP2_HOSTNAME}=https://${CP2_IP}:2380"
      initial-cluster-state: existing
    serverCertSANs:
      - ${CP2_HOSTNAME}
      - ${CP2_IP}
    peerCertSANs:
      - ${CP2_HOSTNAME}
      - ${CP2_IP}
networking:
  dnsDomain: cluster.local
  podSubnet: 10.10.0.0/16
  serviceSubnet: 10.96.0.0/16
kubernetesVersion: "v1.12.4"
controlPlaneEndpoint: "${LB_IP}:6443"
apiServerCertSANs:
- "${LB_NAME}"
imageRepository: "k8s.gcr.io"
unifiedControlPlaneImage: "gcr.io/google_containers/hyperkube-amd64:v1.12.4"
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
EOF
```

#### Move cert files

```
USER=ubuntu # customizable
mkdir -p /etc/kubernetes/pki/etcd
mv /home/${USER}/ca.crt /etc/kubernetes/pki/
mv /home/${USER}/ca.key /etc/kubernetes/pki/
mv /home/${USER}/sa.pub /etc/kubernetes/pki/
mv /home/${USER}/sa.key /etc/kubernetes/pki/
mv /home/${USER}/front-proxy-ca.crt /etc/kubernetes/pki/
mv /home/${USER}/front-proxy-ca.key /etc/kubernetes/pki/
mv /home/${USER}/etcd-ca.crt /etc/kubernetes/pki/etcd/ca.crt
mv /home/${USER}/etcd-ca.key /etc/kubernetes/pki/etcd/ca.key
mv /home/${USER}/admin.conf /etc/kubernetes/admin.conf
```

#### Run kubeadm phase command

```
kubeadm alpha phase certs all --config kubeadm-config.yaml
kubeadm alpha phase kubelet config write-to-disk --config kubeadm-config.yaml
kubeadm alpha phase kubelet write-env-file --config kubeadm-config.yaml
kubeadm alpha phase kubeconfig kubelet --config kubeadm-config.yaml
systemctl start kubelet
```

#### Add etcd

```
export KUBECONFIG=/etc/kubernetes/admin.conf
kubeadm alpha phase etcd local --config kubeadm-config.yaml
kubectl exec -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add ${CP2_HOSTNAME} https://${CP2_IP}:2380

```

#### Deploy control plane

```
kubeadm alpha phase kubeconfig all --config kubeadm-config.yaml
kubeadm alpha phase controlplane all --config kubeadm-config.yaml
kubeadm alpha phase kubelet config annotate-cri --config kubeadm-config.yaml
kubeadm alpha phase mark-master --config kubeadm-config.yaml
```

## Enable Kubectl

- For root user

```
export KUBECONFIG=/etc/kubernetes/admin.conf
```

- For all user

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## Install Network plugin

### Calico

- rbac
    ```
    kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
    ```

- workload

    - download
        ```
        wget https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
        ```
    - edit the value of CALICO_IPV4POOL_CIDR in line 278
        ```
        - name: CALICO_IPV4POOL_CIDR
            value: "10.10.0.0/16"
        ```
    - create
        ```
        kubectl apply -f calico.yaml
        ```

### Flannel

- iptables on each node
    ```
    sysctl net.bridge.bridge-nf-call-iptables=1
    ```

- workload

    ```
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml
    ```

## Join Worker Node

```
swapoff -a
```

```
kubeadm join 192.168.1.253:6443 --token atmc3m.mngv83opwixrl8sk --discovery-token-ca-cert-hash sha256:11277e17a02770f7055d28d74f6492cfb4601785bbfab247d738af64d3811e65
```
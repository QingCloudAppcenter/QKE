# How to install stacked control plane Kubernetes

> https://v1-12.docs.kubernetes.io/docs/setup/independent/high-availability/#stacked-control-plane-nodes

## Prepare

### Docker

Please install [specific version of Docker](install-specific-ver-docker.md). Docker version no more than 18.06.

### Kubeadm

Please install [specific version of Kubeadm and Kubelet](install-specfic-ver-kubeadm.md).

### LB

- Create LB in QingCloud console
- Add TCP rule
- Add firewall rules

## Install Control Plane

### First control plane
#### Add Env

```
export HOST0=192.168.1.3
export HOST1=192.168.1.4
export HOST2=192.168.1.5
```

#### Edit config file

```
apiVersion: kubeadm.k8s.io/v1alpha3
kind: ClusterConfiguration
kubernetesVersion: 1.12.4
apiServerCertSANs:
- "192.168.1.253"
controlPlaneEndpoint: "192.168.1.253:6443"
etcd:
  local:
    extraArgs:
      name: "etcd1"
      listen-client-urls: "https://127.0.0.1:2379,https://192.168.1.3:2379"
      advertise-client-urls: "https://192.168.1.3:2379"
      listen-peer-urls: "https://192.168.1.3:2380"
      initial-advertise-peer-urls: "https://192.168.1.3:2380"
      initial-cluster: "etcd1=https://192.168.1.3:2380"
    serverCertSANs:
      - etcd1
      - 192.168.1.3
    peerCertSANs:
      - etcd1
      - 192.168.1.3
networking:
  dnsDomain: cluster.local
  podSubnet: 172.17.0.0/16
  serviceSubnet: 10.96.0.0/12
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

  kubeadm join 192.168.1.253:6443 --token atmc3m.mngv83opwixrl8sk --discovery-token-ca-cert-hash sha256:11277e17a02770f7055d28d74f6492cfb4601785bbfab247d738af64d3811e65

```

#### Copy Cert files

```
USER=ubuntu 
CONTROL_PLANE_IPS="192.168.1.4 192.168.1.5"
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

#### Edit config file

```
$ cat kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1alpha3
kind: ClusterConfiguration
kubernetesVersion: 1.12.4
apiServerCertSANs:
- "192.168.1.253"
controlPlaneEndpoint: "192.168.1.253:6443"
etcd:
  local:
    extraArgs:
      name: "etcd2"
      listen-client-urls: "https://127.0.0.1:2379,https://192.168.1.4:2379"
      advertise-client-urls: "https://192.168.1.4:2379"
      listen-peer-urls: "https://192.168.1.4:2380"
      initial-advertise-peer-urls: "https://192.168.1.4:2380"
      initial-cluster: "etcd1=https://192.168.1.3:2380,etcd2=https://192.168.1.4:2380"
      initial-cluster-state: existing
    serverCertSANs:
      - etcd2
      - 192.168.1.4
    peerCertSANs:
      - etcd2
      - 192.168.1.4
networking:
  dnsDomain: cluster.local
  podSubnet: 10.10.0.0/16
  serviceSubnet: 10.96.0.0/16
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
export CP0_IP=192.168.1.3
export CP0_HOSTNAME=etcd1
export CP1_IP=192.168.1.4
export CP1_HOSTNAME=etcd2

kubeadm alpha phase etcd local --config kubeadm-config.yaml
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl exec -n kube-system etcd-i-rm3iipqf -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add ${CP1_HOSTNAME} https://${CP1_IP}:2380

```

#### Deploy control plane

```
kubeadm alpha phase kubeconfig all --config kubeadm-config.yaml
kubeadm alpha phase controlplane all --config kubeadm-config.yaml
kubeadm alpha phase kubelet config annotate-cri --config kubeadm-config.yaml
kubeadm alpha phase mark-master --config kubeadm-config.yaml
```

### Third control plane

#### Edit config file

```
apiVersion: kubeadm.k8s.io/v1alpha3
kind: ClusterConfiguration
kubernetesVersion: 1.12.4
apiServerCertSANs:
- "192.168.1.253"
controlPlaneEndpoint: "192.168.1.253:6443"
etcd:
  local:
    extraArgs:
      name: "etcd3"
      listen-client-urls: "https://127.0.0.1:2379,https://192.168.1.5:2379"
      advertise-client-urls: "https://192.168.1.5:2379"
      listen-peer-urls: "https://192.168.1.5:2380"
      initial-advertise-peer-urls: "https://192.168.1.5:2380"
      initial-cluster: "etcd1=https://192.168.1.3:2380,etcd2=https://192.168.1.4:2380,etcd3=https://192.168.1.5:2380"
      initial-cluster-state: existing
    serverCertSANs:
      - etcd3
      - 192.168.1.5
    peerCertSANs:
      - etcd3
      - 192.168.1.5
networking:
  dnsDomain: cluster.local
  podSubnet: 172.17.0.0/16
  serviceSubnet: 10.96.0.0/12
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
export CP0_IP=192.168.1.3
export CP0_HOSTNAME=etcd1
export CP2_IP=192.168.1.5
export CP2_HOSTNAME=etcd3

export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl exec -n kube-system etcd-{MASTER1_HOSTNAME} -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add ${CP2_HOSTNAME} https://${CP2_IP}:2380
kubeadm alpha phase etcd local --config kubeadm-config.yaml
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
            value: "172.17.0.0/16"
        ```

### Flannel

TODO

## Join Worker Node

```
swapoff -a
```

```
kubeadm join 192.168.1.253:6443 --token atmc3m.mngv83opwixrl8sk --discovery-token-ca-cert-hash sha256:11277e17a02770f7055d28d74f6492cfb4601785bbfab247d738af64d3811e65
```
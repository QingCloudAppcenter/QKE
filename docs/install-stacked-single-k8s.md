# Install stacked single master Kubernetes

> https://v1-12.docs.kubernetes.io/docs/setup/independent/create-cluster-kubeadm/

## Prepare

### Docker

Please install [specific version of Docker](install-specific-ver-docker.md). Docker version no more than 18.06.

### Kubeadm

Please install [specific version of Kubeadm and Kubelet](install-specfic-ver-kubeadm.md).

## Install Control Plane

```
$ swapoff -a
```

### Edit config file

```
export MASTER_IP=192.168.1.30
export MASTER_HOSTNAME=$(hostname)
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
---
apiVersion: kubeadm.k8s.io/v1alpha3
kind: ClusterConfiguration
etcd:
  local:
    extraArgs:
      name: "${MASTER_HOSTNAME}"
      listen-client-urls: "https://127.0.0.1:2379,https://${MASTER_IP}:2379"
      advertise-client-urls: "https://${MASTER_IP}:2379"
      listen-peer-urls: "https://${MASTER_IP}:2380"
      initial-advertise-peer-urls: "https://${MASTER_IP}:2380"
      initial-cluster: "${MASTER_HOSTNAME}=https://${MASTER_IP}:2380"
    serverCertSANs:
      - ${MASTER_HOSTNAME}
      - ${MASTER_IP}
    peerCertSANs:
      - ${MASTER_HOSTNAME}
      - ${MASTER_IP}
networking:
  dnsDomain: cluster.local
  podSubnet: 10.10.0.0/16
  serviceSubnet: 10.96.0.0/16
kubernetesVersion: "v1.12.4"
controlPlaneEndpoint: "${MASTER_IP}:6443"
apiServerCertSANs:
- "${MASTER_HOSTNAME}"
imageRepository: "k8s.gcr.io"
unifiedControlPlaneImage: "gcr.io/google_containers/hyperkube-amd64:v1.12.4"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
maxPods: 70
failSwapOn: true
featureGates:
  VolumeSnapshotDataSource: true
  KubeletPluginsWatcher: true
  CSINodeInfo: true
  CSIDriverRegistry: true
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
EOF
```

### Pull Image

```
root@i-3u06kl9n:~# kubeadm config images pull --config kubeadm-config.yaml 
[config/images] Pulled gcr.io/google_containers/hyperkube-amd64:v1.12.4
[config/images] Pulled gcr.io/google_containers/hyperkube-amd64:v1.12.4
[config/images] Pulled gcr.io/google_containers/hyperkube-amd64:v1.12.4
[config/images] Pulled gcr.io/google_containers/hyperkube-amd64:v1.12.4
[config/images] Pulled k8s.gcr.io/pause:3.1
[config/images] Pulled k8s.gcr.io/etcd:3.2.24
[config/images] Pulled k8s.gcr.io/coredns:1.2.2
```

### Install

```
kubeadm init --config kubeadm-config.yaml
...

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

  kubeadm join 192.168.1.3:6443 --token 9byvqq.kevnd4h5emtqvl29 --discovery-token-ca-cert-hash sha256:ac2d985a7af65f530e5dbcc555887a760cb34ffcc128a6c7189a46910aa4fdde
```

### Install Network plugin

#### Calico(stable)

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

#### Flannel

- iptables on each node
    ```
    sysctl net.bridge.bridge-nf-call-iptables=1
    ```

- workload
    - download
      ```
      wget https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml
      ```

    - edit L76
      ```
      75     {
      76       "Network": "10.10.0.0/16",
      77       "Backend": {
      78         "Type": "vxlan"
      79       }
      80     }
      ```

    - create
      ```
      kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml
      ```

## Join worker nodes

```
swapoff -a
```

```
kubeadm join 192.168.1.5:6443 --token 1n5vl0.lfj081ywcq9s5mfm --discovery-token-ca-cert-hash sha256:6af7da9ada51d64a475a2e156b0a318b8bf5149d9fef8614b75eaf933ad462a4
```
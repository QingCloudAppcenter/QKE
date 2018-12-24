# How to install Kubernetes with external Etcd

> https://v1-12.docs.kubernetes.io/docs/setup/independent/high-availability/

## Prepare

### Docker

Please install [specific version of Docker](install-specific-ver-docker.md). Docker version no more than 18.06.

### Kubeadm

Please install [specific version of Kubeadm and Kubelet](install-specfic-ver-kubeadm.md).

### LB

- Create LB in QingCloud console
- Add TCP rule
- Add firewall rules

## Install External Etcd

### Run kubelet (on each node)

```
cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --address=127.0.0.1 --pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true
Restart=always
EOF

systemctl daemon-reload
systemctl restart kubelet
```

### Generate Config file on first node

```
export HOST0=192.168.1.6
export HOST1=192.168.1.7
export HOST2=192.168.1.8

mkdir -p /tmp/${HOST0}/ /tmp/${HOST1}/ /tmp/${HOST2}/

ETCDHOSTS=(${HOST0} ${HOST1} ${HOST2})
NAMES=("infra0" "infra1" "infra2")

for i in "${!ETCDHOSTS[@]}"; do
HOST=${ETCDHOSTS[$i]}
NAME=${NAMES[$i]}
cat << EOF > /tmp/${HOST}/kubeadmcfg.yaml
apiVersion: "kubeadm.k8s.io/v1alpha3"
kind: ClusterConfiguration
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        peerCertSANs:
        - "${HOST}"
        extraArgs:
            initial-cluster: infra0=https://${ETCDHOSTS[0]}:2380,infra1=https://${ETCDHOSTS[1]}:2380,infra2=https://${ETCDHOSTS[2]}:2380
            initial-cluster-state: new
            name: ${NAME}
            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380
EOF
done
```

### Generate CA on first node

```
kubeadm alpha phase certs etcd-ca
```

### Create Cert on first node

```
kubeadm alpha phase certs etcd-server --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm alpha phase certs etcd-peer --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm alpha phase certs etcd-healthcheck-client --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm alpha phase certs apiserver-etcd-client --config=/tmp/${HOST2}/kubeadmcfg.yaml
cp -R /etc/kubernetes/pki /tmp/${HOST2}/

find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete

kubeadm alpha phase certs etcd-server --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm alpha phase certs etcd-peer --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm alpha phase certs etcd-healthcheck-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm alpha phase certs apiserver-etcd-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
cp -R /etc/kubernetes/pki /tmp/${HOST1}/
find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete

kubeadm alpha phase certs etcd-server --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm alpha phase certs etcd-peer --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm alpha phase certs etcd-healthcheck-client --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm alpha phase certs apiserver-etcd-client --config=/tmp/${HOST0}/kubeadmcfg.yaml

find /tmp/${HOST2} -name ca.key -type f -delete
find /tmp/${HOST1} -name ca.key -type f -delete
```

### Copy files on rest of nodes

```
 USER=ubuntu
 HOST=${HOST2}
 scp -r /tmp/${HOST}/* ${USER}@${HOST}:
```

- Login node

```
 USER@HOST $ sudo -Es
 root@HOST $ chown -R root:root pki
 root@HOST $ mv pki /etc/kubernetes/
```

### Create static pod manifests on each nodes

```
root@HOST0 $ kubeadm alpha phase etcd local --config=/tmp/${HOST0}/kubeadmcfg.yaml
root@HOST1 $ kubeadm alpha phase etcd local --config=/home/ubuntu/kubeadmcfg.yaml
root@HOST2 $ kubeadm alpha phase etcd local --config=/home/ubuntu/kubeadmcfg.yaml
```

### Verify
```
docker run --rm -it \
--net host \
-v /etc/kubernetes:/etc/kubernetes quay.io/coreos/etcd:v3.2.18 etcdctl \
--cert-file /etc/kubernetes/pki/etcd/peer.crt \
--key-file /etc/kubernetes/pki/etcd/peer.key \
--ca-file /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://192.168.1.6:2379 cluster-health
...
cluster is healthy
```

### Copy Etcd files to Control plane

```
cat << EOF > etcd-pki-files.txt
/etc/kubernetes/pki/etcd/ca.crt
/etc/kubernetes/pki/apiserver-etcd-client.crt
/etc/kubernetes/pki/apiserver-etcd-client.key
EOF
```
```
tar -czf etcd-pki.tar.gz -T etcd-pki-files.txt
```
```
USER=ubuntu
CONTROL_PLANE_HOSTS="192.168.1.3 192.168.1.4 192.168.1.5"
for host in $CONTROL_PLANE_HOSTS; do
    scp etcd-pki.tar.gz "${USER}"@$host:
done
```

## Install Control Plane

### Set up first control plane node

#### Extrace etcd cert

```
mkdir -p /etc/kubernetes/pki
tar -xzf etcd-pki.tar.gz -C /etc/kubernetes/pki --strip-components=3
```

#### Create kubeadm config file

```
apiVersion: kubeadm.k8s.io/v1alpha3
kind: ClusterConfiguration
kubernetesVersion: 1.12.4
apiServerCertSANs:
- "192.168.1.253"
controlPlaneEndpoint: "192.168.1.253:6443"
etcd:
    external:
        endpoints:
        - https://192.168.1.3:2379
        - https://192.168.1.4:2379
        - https://192.168.1.5:2379
        caFile: /etc/kubernetes/pki/etcd/ca.crt
        certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
        keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
networking:
  dnsDomain: cluster.local
  podSubnet: 10.10.0.0/16
  serviceSubnet: 10.96.0.0/16
```

#### Run kubeadm init

```
 kubeadm init --config kubeadm-config.yaml 
 
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

  kubeadm join 192.168.1.253:6443 --token h0apcb.v6dxkoa7smqclbqz --discovery-token-ca-cert-hash sha256:63764d810ddcea72f0cc70faa0b7109a1116893c8bef32e7c707ab04828a0633
```

#### Copy cert files

```
cat << EOF > certificate_files.txt
/etc/kubernetes/pki/ca.crt
/etc/kubernetes/pki/ca.key
/etc/kubernetes/pki/sa.key
/etc/kubernetes/pki/sa.pub
/etc/kubernetes/pki/front-proxy-ca.crt
/etc/kubernetes/pki/front-proxy-ca.key
EOF
```

```
tar -czf control-plane-certificates.tar.gz -T certificate_files.txt
```
```
USER=ubuntu # customizable
CONTROL_PLANE_IPS="192.168.1.4 192.168.1.5"
for host in ${CONTROL_PLANE_IPS}; do
    scp control-plane-certificates.tar.gz "${USER}"@$host:
done
```

### Other control plane nodes
#### Extrace cert files
```
cd /home/ubuntu
mkdir -p /etc/kubernetes/pki
tar -xzf etcd-pki.tar.gz -C /etc/kubernetes/pki --strip-components 3
tar -xzf control-plane-certificates.tar.gz -C /etc/kubernetes/pki --strip-components 3
```

#### Kubeadm join

```
kubeadm join 192.168.1.253:6443 --token h0apcb.v6dxkoa7smqclbqz --discovery-token-ca-cert-hash sha256:63764d810ddcea72f0cc70faa0b7109a1116893c8bef32e7c707ab04828a0633 --ignore-preflight-errors=FileAvailable--etc-kubernetes-pki-ca.crt  --experimental-control-plane
```

## Install Network Plugin

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

## Add Worker Node

```
kubeadm join 192.168.1.253:6443 --token h0apcb.v6dxkoa7smqclbqz --discovery-token-ca-cert-hash sha256:63764d810ddcea72f0cc70faa0b7109a1116893c8bef32e7c707ab04828a0633
```
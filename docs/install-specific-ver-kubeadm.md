# How to install specific version of Kubeadm and Kubelet

## Disable swap

```
$ swapoff -a
```

- verify
```
$ free -m
              total        used        free      shared  buff/cache   available
Mem:           7982         138        7065          11         778        7558
Swap:             0           0           0
```

## Install dependency

### Step 1
```
apt-get update && apt-get install -y apt-transport-https curl
...
apt-transport-https is already the newest version (1.2.29).
curl is already the newest version (7.47.0-1ubuntu2.11).
0 upgraded, 0 newly installed, 0 to remove and 150 not upgraded.
```

### Step 2
```
# curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
```

### Step 3
```
# apt-get update
...
Fetched 31.4 kB in 5s (6,184 B/s)
Reading package lists... Done
```

### Step 4
```
# apt-get install -y kubelet=1.12.4-00 kubeadm=1.12.4-00 kubectl=1.12.4-00
```

### Step 5
```
# apt-mark hold kubelet kubeadm kubectl
kubelet set on hold.
kubeadm set on hold.
kubectl set on hold.
```


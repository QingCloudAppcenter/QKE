# 构建虚拟机镜像

- 基于 Ubuntu 16.04.4 构建，切换到 root 用户

- 下载代码仓库
```bash
apt-get install -y git
git clone https://github.com/QingCloudAppcenter/kubesphere.git /opt/kubernetes

git clone https://github.com/wnxn/kubesphere-1.git /opt/kubernetes
cd /opt/kubernetes
```

- 下载所需内容

```bash
image/build-base.sh
```

- 拷贝 confd 文件
```
rm -rf /etc/confd/conf.d/k8s/*
rm -rf /etc/confd/templates/k8s/*
```

```
cp -r /opt/kubernetes/confd/conf.d /etc/confd/
cp -r /opt/kubernetes/confd/templates /etc/confd/
```

- 修改 Kubelet 启动 service 文件

添加参数，为健康检查用。待 Kubeadm 能够正常添加参数，此步可删去。

```
vim /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --anonymous-auth=true --authorization-mode=AlwaysAllow"
```

- 执行 image 内 update-overlay2.sh
执行前确保当前主机没有在 /var/lib/docker/overlay2 内创建软链接，链接镜像层。
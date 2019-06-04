# 构建虚拟机镜像

- 基于 Ubuntu 16.04.4 构建，切换到 root 用户

- Clear Command History
``
history -c
```

- 下载代码仓库
```bash
apt-get install -y git
git clone https://github.com/QingCloudAppcenter/kubesphere.git /opt/kubernetes
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
cp /opt/kubernetes/k8s/linux/kubelet/10-kubeadm.conf /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
```

- 执行 image 内 update-overlay2.sh
执行前确保当前主机没有在 /var/lib/docker/overlay2 内创建软链接，链接镜像层。

# 修改 KVM 镜像里 Docker 镜像


```
mv /var/lib/docker/overlay2/l /opt/overlay2/
rm -rf /var/lib/docker/overlay2/*
mv /opt/overlay2/* /var/lib/docker/overlay2/
```
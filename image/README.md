# 构建虚拟机镜像

- 基于 Ubuntu 18.04.1（bionic1x64c） 构建，切换到 root 用户

- 下载代码仓库
```bash
apt-get install -y git
git clone https://github.com/QingCloudAppcenter/QKE.git /opt/kubernetes
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

- 强制用户登陆时修改口令
```
chage -d 0 root
```

- 清理命令行历史
```
> /var/log/syslog
> ~/.bash_history && history -c
history
```

# 对于新增功能点
开发者开发容器镜像、confd、脚本相关功能，可以复用已有的 KVM 镜像。

## 修改 KVM 镜像里 Docker 镜像
对于容器镜像更新、新增、删除可以用本方法。
- 删除软连接镜像层，将实际镜像层放到 docker 文件夹里
```
mv /var/lib/docker/overlay2/l /opt/overlay2/
rm -rf /var/lib/docker/overlay2/*
mv /opt/overlay2/* /var/lib/docker/overlay2/
```
- 查看镜像层情况
```
`/opt/overlay2` 文件夹内不应有内容
`/var/lib/docker/overlay2` 文件夹内不应有软链接
```

- 更新镜像命令
```
docker rmi XXX
docker pull XXX
```
- 添加软链接镜像层
```
/opt/kubernetes/image/update-overlay2.sh
```

## 更新 confd 文件
- 对于 confd 文件更新，可以用本方法。
```
rm -rf /etc/confd/conf.d/k8s/*
rm -rf /etc/confd/templates/k8s/*
```

```
cp -r /opt/kubernetes/confd/conf.d /etc/confd/
cp -r /opt/kubernetes/confd/templates /etc/confd/
```

# 参考资料
## 用户密码修改
参考资料：https://blog.csdn.net/QiaoRui_/article/details/81172109

- 查看用户密码设定情况
```
chage -l root
```

- 强制用户登陆时修改口令
```
chage -d 0 root
```

## 检查软件安装情况
```
dpkg -s NAME
```

## 查看 metadata

```
curl http://metadata/self
```

## 刷新 confd 文件

```
/opt/qingcloud/app-agent/bin/confd -onetime
```
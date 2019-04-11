# 设计

# 功能点实现

## 持久化文件

/var/lib/docker -> /data/var/lib/docker
/etc/kubernetes -> /data/kubernetes
/var/lib/kubelet -> /data/var/lib/kubelet
/var/lib/etcd -> /data/var/lib/etcd
/data/env.sh
/root/.kube -> /data/root/kube

## 其他重要目录
/data/env.sh
/etc/kubernetes/kubeadm-config.yaml
/etc/kubernetes/init-token.metad

# 


# 测试

## 集成测试用例

- 网络插件：Calico，Flannel , 不可修改
- 主机类型：性能型，超高性能型
- Service Subnet，, 不可修改，kubeadm-config.yaml, kubeadm 生成新的 static pod 文件，
- Pod Subnet, 不可修改
- DNS Domain, 不可修改
- 节点端口范围： 30000-32767（默认）, 不可修改
- Max Pods： 60（默认），可修改
- Proxy Mode：ipvs（默认），iptables，没有这个选项
- 主机 Hosts 记录，没有这个选项
- 镜像仓库地址，，可修改
- 非安全镜像仓库地址，，可修改
- 私有镜像服务端，可修改
- docker 网桥掩码，可修改 （建议取消修改这个参数）
- 日志保留天数，，可修改
- Kubernetes 日志级别，可修改
- 关机重启内容不丢失
- Node 扩容
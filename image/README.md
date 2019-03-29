# 构建虚拟机镜像

* base ubuntu 16.04.4
* switch to root 

```bash
gitBranch=$1
apt-get install -y git
git clone https://github.com/QingCloudAppcenter/kubesphere.git /opt/kubesphere
cd /opt/kubesphere
if [ -n "$gitBranch" ]
then
  git fetch origin $gitBranch:$gitBranch
  git checkout $gitBranch
  git branch --set-upstream-to=origin/$gitBranch $gitBranch
  git pull
fi
/opt/kubesphere/image/build-1.sh

```

# 安装 Kubelet, Kubeadm

- apt-get install kubeadm=1.12.7-00 kubelet=1.12.7-00 kubectl=1.12.7-00 kubernetes-cni=0.7.5-00

# 构建之后
- 手动修改 vim /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
- Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --anonymous-auth=true --authorization-mode=AlwaysAllow"

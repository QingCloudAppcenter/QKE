SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

upgrade_k8s_dir
# copy confd files

rm -rf /etc/confd/conf.d/k8s/*
rm -rf /etc/confd/templates/k8s/*
cp -r /upgrade/kubernetes/confd/conf.d /etc/confd/
cp -r /upgrade/kubernetes/confd/templates /etc/confd/
/opt/qingcloud/app-agent/bin/confd -onetime
systemctl stop kubelet
cp /upgrade/kubelet /usr/bin/kubelet
cp /upgrade/kubectl /usr/bin/kubectl
cp /upgrade/kubeadm /usr/bin/kubeadm

systemctl start kubelet
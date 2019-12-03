#!/usr/bin/env bash

# Copyright 2018 The KubeSphere Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")
KUBEADM_CONFIG_PATH="/opt/kubernetes/k8s/kubernetes/kubeadm-config.yaml"
KUBEADM_EIP_PATH="/opt/kubernetes/k8s/kubernetes/kubeadm-eip.yaml"
KUBECONFIG="/etc/kubernetes/admin.conf"
NODE_INIT_LOCK="/data/kubernetes/node-init.lock"
PERMIT_RELOAD_LOCK="/data/kubernetes/permit-reload.lock"
CLIENT_INIT_LOCK="/data/kubernetes/client-init.lock"
UPGRADE_DIR="/upgrade"
ORIGINAL_DIR=("/var/lib/docker" "/root/.docker"
"/var/lib/etcd" "/var/lib/kubelet" 
"/etc/kubernetes" "/root/.kube")
DATA_DIR=("/data/var/lib/docker" "/data/root/.docker"
"/data/var/lib/etcd" "/data/var/lib/kubelet"
"/data/kubernetes" "/data/root/.kube")
PATH=$PATH:/usr/local/bin
source "/data/env.sh"
source "${K8S_HOME}/version"

#set -o errexit
set -o nounset
set -o pipefail

function fail {
  echo $1 >&2
  exit 1
}

function log {
  logger -t appctl $@
}

function retry {
  local n=1
  local max=60
  local delay=2
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        log "Command failed. Attempt $n/$max:"
        sleep $delay;
      else
        fail "The command has failed after $n attempts."
      fi
    }
  done
}

function wait_installer_job_completed(){
  local n=1
  local max=200
  local delay=10

  while true; do
    job_status=`kubectl get job -n kubesphere-system kubesphere-installer -o jsonpath='{.status.conditions[0].type}'`
    [ "$job_status" == "Complete" ] && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        log "Command failed. Attempt $n/$max:"
        sleep $delay;
      else
        fail "The command has failed after $n attempts."
      fi
    }
  done
}

function get_node_status(){
    local status=$(kubectl get nodes/${HOST_INSTANCE_ID} --kubeconfig /etc/kubernetes/kubelet.conf -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    echo ${status}
}

function drain_node(){
    retry kubectl drain  --kubeconfig /etc/kubernetes/admin.conf  --delete-local-data=true --ignore-daemonsets=true --force $1 
    return $?
}

function wait_etcd(){
    is_systemd_active etcd
}

function is_systemd_active(){
    retry systemctl is-active -q $1
}

# Link dir from data volume
function ensure_dir(){
    for i in "${!ORIGINAL_DIR[@]}"
    do
        if [ -d ${ORIGINAL_DIR[$i]} ] && [ ! -L ${ORIGINAL_DIR[$i]} ]
        then
            retry rm -rf ${ORIGINAL_DIR[$i]}
        fi
        ln -sfT ${DATA_DIR[$i]} ${ORIGINAL_DIR[$i]}
    done
}

function make_dir(){
    retry mkdir -p /data/var/lib/kubelet
    retry mkdir -p /data/root
    retry mkdir -p /root/.kube
    retry mkdir -p /etc/kubernetes/pki
}

# Copy dir into data volume
function link_dir(){
    log "link dir"
    log "make dir"
    make_dir
    log "finish make dir"
    for i in "${!ORIGINAL_DIR[@]}"
    do
        if [ -d ${ORIGINAL_DIR[$i]} ] && [ ! -L ${ORIGINAL_DIR[$i]} ]
        then
            log "mv" ${ORIGINAL_DIR[$i]} "to" ${DATA_DIR[$i]}
            mv ${ORIGINAL_DIR[$i]} $(dirname ${DATA_DIR[$i]})
            log "ln" ${ORIGINAL_DIR[$i]} "with" ${DATA_DIR[$i]}
            ln -sfT ${DATA_DIR[$i]} ${ORIGINAL_DIR[$i]}
            log "finished ln" ${ORIGINAL_DIR[$i]} "with" ${DATA_DIR[$i]}
        fi
    done
}

function wait_apiserver(){
    while ! curl --output /dev/null --silent --fail http://localhost:8080/healthz;
    do
        echo "waiting k8s api server" && sleep 2
    done;
}

function docker_stop_rm_all () {
    for i in `docker ps -q`
    do
        docker stop $i;
    done
    for i in `docker ps -aq`
    do
        docker rm -f $i;
    done
}

function docker_stop () {
  retry systemctl stop docker
}

function set_password(){
    echo "root:k8s" |chpasswd
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    systemctl restart ssh
    chage -d 0 root
}

function install_network_plugin(){
    case "${NETWORK_PLUGIN}" in
    "calico")
        retry kubectl apply -f /opt/kubernetes/k8s/addons/calico/calico-rbac.yaml  --kubeconfig ${KUBECONFIG}
        retry kubectl apply -f /opt/kubernetes/k8s/addons/calico/calico-deploy.yaml  --kubeconfig ${KUBECONFIG}
        ;;
    "flannel")
        retry kubectl apply -f /opt/kubernetes/k8s/addons/flannel/flannel-deploy.yaml  --kubeconfig ${KUBECONFIG}
        ;;
    *)
        echo "Invalid network plugin" ${NETWORK_PLUGIN} >&2
        exit -1
        ;;
    esac
}

function install_kube_proxy(){
    if [ ${ENV_MASTER_COUNT} -gt 1 ]
    then
        lb_ip=`cat /etc/kubernetes/loadbalancer_ip`
        replace_kv /opt/kubernetes/k8s/addons/kube-proxy/kube-proxy-cm.yaml server SHOULD_BE_REPLACED $(echo ${lb_ip})
    fi
    retry kubectl apply -f /opt/kubernetes/k8s/addons/kube-proxy/rbac.yaml  --kubeconfig ${KUBECONFIG}
    retry kubectl apply -f /opt/kubernetes/k8s/addons/kube-proxy/kube-proxy-cm.yaml  --kubeconfig ${KUBECONFIG}
    retry kubectl apply -f /opt/kubernetes/k8s/addons/kube-proxy/kube-proxy-ds.yaml  --kubeconfig ${KUBECONFIG}
}

function join_node(){
    if [ -f "${NODE_INIT_LOCK}" ]; then
        log "node has joined."
        return
    fi

    local initToken=`cat /opt/kubernetes/k8s/kubernetes/init-token.metad`
    while [ -z "${initToken}" ]
    do
        log "sleep for wait init token for 2 second"
        sleep 2
        initToken=`cat /opt/kubernetes/k8s/kubernetes/init-token.metad`
    done

    log "Token: ${initToken}"
    retry ${initToken}
    touch ${NODE_INIT_LOCK}
    chmod 400 ${NODE_INIT_LOCK}
}

function install_csi(){
    retry kubectl create configmap csi-qingcloud --from-file=config.yaml=/etc/qingcloud/client.yaml --namespace=kube-system  --kubeconfig ${KUBECONFIG}
    retry kubectl apply -f /opt/kubernetes/k8s/addons/qingcloud-csi/csi-release-v1.1.0.yaml  --kubeconfig ${KUBECONFIG}
    retry kubectl apply -f /opt/kubernetes/k8s/addons/qingcloud-csi/csi-sc.yaml  --kubeconfig ${KUBECONFIG}
}

function uninstall_csi(){
    retry kubectl delete configmap csi-qingcloud --namespace=kube-system  --kubeconfig ${KUBECONFIG}
    retry kubectl delete -f /opt/kubernetes/k8s/addons/qingcloud-csi/csi-release-v1.1.0.yaml  --kubeconfig ${KUBECONFIG}
    retry kubectl delete -f /opt/kubernetes/k8s/addons/qingcloud-csi/csi-sc.yaml  --kubeconfig ${KUBECONFIG}

}

function install_coredns(){
    kubeadm init phase addon coredns --config ${KUBEADM_CONFIG_PATH}  --kubeconfig ${KUBECONFIG}
    retry kubectl apply -f /opt/kubernetes/k8s/addons/coredns/coredns-rbac.yaml  --kubeconfig ${KUBECONFIG}
    retry kubectl apply -f /opt/kubernetes/k8s/addons/coredns/coredns-deploy.yaml  --kubeconfig ${KUBECONFIG}
    retry kubectl apply -f /opt/kubernetes/k8s/addons/coredns/coredns-cm.yaml  --kubeconfig ${KUBECONFIG}
}

function install_tiller(){
    retry kubectl apply -f /opt/kubernetes/k8s/addons/tiller/tiller-sa.yaml  --kubeconfig ${KUBECONFIG}
    retry kubectl apply -f /opt/kubernetes/k8s/addons/tiller/tiller-deploy.yaml  --kubeconfig ${KUBECONFIG}
    retry kubectl apply -f /opt/kubernetes/k8s/addons/tiller/tiller-svc.yaml  --kubeconfig ${KUBECONFIG}
}

function install_cloud_controller_manager(){
    retry kubectl create configmap lbconfig --from-file=/opt/kubernetes/k8s/addons/cloud-controller-manager/qingcloud.yaml -n kube-system  --kubeconfig ${KUBECONFIG}
    retry kubectl create secret generic qcsecret --from-file=config.yaml=/etc/qingcloud/client.yaml -n kube-system  --kubeconfig ${KUBECONFIG}
    retry kubectl apply -f /opt/kubernetes/k8s/addons/cloud-controller-manager/cloud-controller-manager.yaml  --kubeconfig ${KUBECONFIG}
}

# Uninstall cloud controller manager in QKE v1.0.x
function uninstall_cloud_controller_manager(){
    retry kubectl delete secret qcsecret -n kube-system  --kubeconfig ${KUBECONFIG}
    retry kubectl delete -f /opt/kubernetes/k8s/addons/cloud-controller-manager/cloud-controller-manager.yaml  --kubeconfig ${KUBECONFIG}
}

function replace_kv(){
    filepath=$1
    key=$2
    symbolvalue=$3
    actualvalue=$4
    if [ -f $1 ]
    then
        sed "/${key}/s@${symbolvalue}@${actualvalue}@g" -i ${filepath}
    fi
}

function install_kubesphere(){
    log "install_kubesphere: create kubesphere-system namespace"
    retry kubectl create ns  kubesphere-system
    log "install_kubesphere: create kubesphere-monitoring-system namespace"
    retry kubectl create ns kubesphere-monitoring-system

    if [ ! -f "/etc/kubernetes/pki/ca.crt" ] || [ ! -f "/etc/kubernetes/pki/ca.key" ] || 
    [ ! -f "/etc/kubernetes/pki/front-proxy-client.crt" ] || [ ! -f "/etc/kubernetes/pki/front-proxy-client.key" ]
    then
        log "install_kubesphere: scp cert"
        scp master1:/etc/kubernetes/pki/* /etc/kubernetes/pki/
    fi

    log "install_kubesphere: create kubesphere-ca secret"
    retry kubectl -n kubesphere-system create secret generic kubesphere-ca \
    --from-file=ca.crt=/etc/kubernetes/pki/ca.crt \
    --from-file=ca.key=/etc/kubernetes/pki/ca.key 

    log "install_kubesphere: create front-proxy-client secret"
    retry kubectl -n kubesphere-system create secret generic front-proxy-client \
    --from-file=front-proxy-client.crt=/etc/kubernetes/pki/front-proxy-client.crt \
    --from-file=front-proxy-client.key=/etc/kubernetes/pki/front-proxy-client.key

    log "install_kubesphere: create kube-etcd-client-certs secret"
    retry kubectl -n kubesphere-monitoring-system create secret generic kube-etcd-client-certs
    if [ "${CLUSTER_ELK_ID}" != "null" ]
    then
        log "install_kubesphere: create external elk svc"
        retry kubectl apply -f /opt/kubernetes/k8s/kubesphere/logging/external-elk-svc.yaml
    fi

    log "install_kubesphere: install ks-only"
    retry kubectl apply -f /opt/kubernetes/k8s/kubesphere/installer/kubesphere-installer.yaml

    log "install_kubesphere: wait ks-only installer job complete"
    wait_installer_job_completed

    log "install_kubesphere: create ks console svc"
    retry kubectl apply -f /opt/kubernetes/k8s/kubesphere/ks-console/ks-console-svc.yaml
}

function get_loadbalancer_ip(){
    lb_ip=`cat /etc/kubernetes/loadbalancer_ip`
    echo "${lb_ip}"
}

function replace_kubeadm_config_lb_ip(){
    lb_ip=`cat /etc/kubernetes/loadbalancer_ip`
    if [ "${lb_ip}" == "" ]
    then
        return
    fi
    replace_kv ${KUBEADM_CONFIG_PATH} controlPlaneEndpoint SHOULD_BE_REPLACED $(echo ${lb_ip})
}

function replace_kubeadm_eip_lb_ip(){
    lb_ip=`cat /etc/kubernetes/loadbalancer_ip`
    if [ "${lb_ip}" == "" ]
    then
        return
    fi
    replace_kv ${KUBEADM_EIP_PATH} controlPlaneEndpoint SHOULD_BE_REPLACED $(echo ${lb_ip})
}

function replace_hosts_lb_ip(){
    lb_ip=`cat /etc/kubernetes/loadbalancer_ip`
    if [ "${lb_ip}" == "" ]
    then
        return
    fi
    replace_kv /etc/hosts loadbalancer SHOULD_BE_REPLACED $(echo ${lb_ip})
}

function is_tiller_available(){
    avail_num=`kubectl -n kube-system get deploy/tiller-deploy -o jsonpath='{.status.availableReplicas}'`
    if [ "${avail_num}" == ""  ]
    then
        return -2
    fi
    if [ ${avail_num} -ge 1 ]
    then
        return 0
    else
        return -1
    fi
}

function restart_kubernetes_control_plane(){
    log "restart kubelet"
    systemctl restart kubelet
    if [ "${HOST_ROLE}" == "master" ]
    then
        log "restart kubernetes apiserver"
        kill -9 $(pidof kube-apiserver)
        log "restart kubernetes controller manager"
        kill -9 $(pidof kube-controller-manager)
        log "restart kubernetes scheduler"
        kill -9 $(pidof kube-scheduler)
    fi
}

function kubelet_active(){
  retry systemctl is-active kubelet >/dev/null 2>&1
}

function docker_active(){
  retry systemctl is-active docker >/dev/null 2>&1
}

function upgrade_k8s_image(){
    # load images
    docker load < ${UPGRADE_DIR}/hyperkube-v1.15.5.img
    docker load < ${UPGRADE_DIR}/pause-3.1.img

    # Network
    docker load < ${UPGRADE_DIR}/coredns-1.3.1.img
    docker load < ${UPGRADE_DIR}/calico-node-v3.8.4.img
    docker load < ${UPGRADE_DIR}/calico-cni-v3.8.4.img
    docker load < ${UPGRADE_DIR}/calico-kube-controllers-v3.8.4.img
    docker load < ${UPGRADE_DIR}/calico-pod2daemon-flexvol-v3.8.4.img
    docker load < ${UPGRADE_DIR}/flannel-v0.11.0-amd64.img
    docker load < ${UPGRADE_DIR}/cloud-controller-manager-v1.4.2.img

    # Storage
    docker load < ${UPGRADE_DIR}/csi-provisioner-v1.4.0.img
    docker load < ${UPGRADE_DIR}/csi-attacher-v2.0.0.img
    docker load < ${UPGRADE_DIR}/csi-snapshotter-v1.2.2.img
    docker load < ${UPGRADE_DIR}/csi-resizer-v0.2.0.img
    docker load < ${UPGRADE_DIR}/csi-qingcloud-v1.1.0.img
    docker load < ${UPGRADE_DIR}/csi-node-driver-registrar-v1.2.0.img

    # tiller
    docker load < ${UPGRADE_DIR}/tiller-v2.12.3.img
}

function upgrade_copy_confd(){
    rm -rf /etc/confd/conf.d/k8s/*
    rm -rf /etc/confd/templates/k8s/*
    cp -r ${UPGRADE_DIR}/kubernetes/confd/conf.d /etc/confd/
    cp -r ${UPGRADE_DIR}/kubernetes/confd/templates /etc/confd/
    /opt/qingcloud/app-agent/bin/confd -onetime
}

function upgrade_kubelet(){
    systemctl stop kubelet
    cp /upgrade/kubelet /usr/bin/kubelet
    cp /upgrade/kubectl /usr/bin/kubectl
    cp /upgrade/kubeadm /usr/bin/kubeadm
    systemctl start kubelet
}

function upgrade_csi(){
    uninstall_csi
    install_csi
}

function upgrade_cloud_controller_manager(){
    uninstall_cloud_controller_manager
    install_cloud_controller_manager
}
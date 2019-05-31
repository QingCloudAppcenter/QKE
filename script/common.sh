#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")
KUBEADM_CONFIG_PATH="/data/kubernetes/kubeadm-config.yaml"
KUBECONFIG="/etc/kubernetes/admin.conf"
NODE_INIT_LOCK="/data/kubernetes/node-init.lock"
CLIENT_INIT_LOCK="/data/kubernetes/client-init.lock"
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

function retry {
  local n=1
  local max=60
  local delay=2
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Command failed. Attempt $n/$max:"
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
    kubectl drain  --kubeconfig /etc/kubernetes/admin.conf  --delete-local-data=true --ignore-daemonsets=true --force $1 
    return $?
}

function wait_etcd(){
    is_systemd_active etcd
}

function is_systemd_active(){
    retry systemctl is-active $1 > /dev/null 2>&1
}

# Link dir from data volume
function ensure_dir(){
    for i in "${!ORIGINAL_DIR[@]}"
    do
        if [ -d ${ORIGINAL_DIR[$i]} ] && [ ! -L ${ORIGINAL_DIR[$i]} ]
        then
            rm -rf ${ORIGINAL_DIR[$i]}
        fi
        ln -sfT ${DATA_DIR[$i]} ${ORIGINAL_DIR[$i]}
    done
}

function make_dir(){
    mkdir -p /data/var/lib
    mkdir -p /data/root
    mkdir -p /root/.kube
    mkdir -p /etc/kubernetes/pki
}

# Copy dir into data volume
function link_dir(){
    echo $(date "+%Y-%m-%d %H:%M:%S") "link dir"
    echo $(date "+%Y-%m-%d %H:%M:%S") "make dir"
    make_dir
    echo $(date "+%Y-%m-%d %H:%M:%S") "finish make dir"
    for i in "${!ORIGINAL_DIR[@]}"
    do
        if [ -d ${ORIGINAL_DIR[$i]} ] && [ ! -L ${ORIGINAL_DIR[$i]} ]
        then
            echo $(date "+%Y-%m-%d %H:%M:%S") "mv" ${ORIGINAL_DIR[$i]} "to" ${DATA_DIR[$i]}
            mv ${ORIGINAL_DIR[$i]} $(dirname ${DATA_DIR[$i]})
            echo $(date "+%Y-%m-%d %H:%M:%S") "ln" ${ORIGINAL_DIR[$i]} "with" ${DATA_DIR[$i]}
            ln -sfT ${DATA_DIR[$i]} ${ORIGINAL_DIR[$i]}
            echo $(date "+%Y-%m-%d %H:%M:%S") "finished ln" ${ORIGINAL_DIR[$i]} "with" ${DATA_DIR[$i]}
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
}

function install_network_plugin(){
    case "${NETWORK_PLUGIN}" in
    "calico")
        kubectl apply -f /opt/kubernetes/k8s/addons/calico/calico-rbac.yaml
        kubectl apply -f /opt/kubernetes/k8s/addons/calico/calico-deploy.yaml
        ;;
    "flannel")
        kubectl apply -f /opt/kubernetes/k8s/addons/flannel/flannel-deploy.yaml
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
    kubectl apply -f /opt/kubernetes/k8s/addons/kube-proxy/rbac.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/kube-proxy/kube-proxy-cm.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/kube-proxy/kube-proxy-ds.yaml
}

function join_node(){
    if [ -f "${NODE_INIT_LOCK}" ]; then
        echo "node has joined."
        return
    fi

    local initToken=`cat /data/kubernetes/init-token.metad`
    while [ -z "${initToken}" ]
    do
        echo "sleep for wait init token for 2 second"
        sleep 2
        initToken=`cat /data/kubernetes/init-token.metad`
    done

    echo "Token: ${initToken}"
    retry ${initToken}

    touch ${NODE_INIT_LOCK}
}

function install_csi(){
    kubectl create configmap csi-qingcloud --from-file=config.yaml=/etc/qingcloud/client.yaml --namespace=kube-system
    kubectl apply -f /opt/kubernetes/k8s/addons/qingcloud-csi/csi-secret.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/qingcloud-csi/csi-controller-rbac.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/qingcloud-csi/csi-node-rbac.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/qingcloud-csi/csi-controller-sts.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/qingcloud-csi/csi-node-ds.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/qingcloud-csi/csi-sc.yaml
}

function install_coredns(){
    kubeadm init phase addon coredns --config ${KUBEADM_CONFIG_PATH}
    kubectl apply -f /opt/kubernetes/k8s/addons/coredns/coredns-rbac.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/coredns/coredns-deploy.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/coredns/coredns-cm.yaml
}

function install_tiller(){
    kubectl apply -f /opt/kubernetes/k8s/addons/tiller/tiller-sa.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/tiller/tiller-deploy.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/tiller/tiller-svc.yaml
}

function install_cloud_controller_manager(){
    kubectl create secret generic qcsecret --from-file=/etc/qingcloud/client.yaml -n kube-system
    kubectl apply -f /opt/kubernetes/k8s/addons/cloud-controller-manager/cloud-controller-manager.yaml
}

function docker_login(){
    if [ ! -z "${ENV_PRIVATE_REGISTRY}" ]
    then
        if [ ! -z "${ENV_DOCKERHUB_USERNAME}" ] && [ ! -z "${ENV_DOCKERHUB_PASSWORD}" ]
        then
            retry docker login ${ENV_PRIVATE_REGISTRY} -u ${ENV_DOCKERHUB_USERNAME} -p ${ENV_DOCKERHUB_PASSWORD}
        fi
    else
        if [ ! -z "${ENV_DOCKERHUB_USERNAME}" ] && [ ! -z "${ENV_DOCKERHUB_PASSWORD}" ]
        then
            retry docker login dockerhub.qingcloud.com -u ${ENV_DOCKERHUB_USERNAME} -p ${ENV_DOCKERHUB_PASSWORD}
        fi
    fi
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

function makeup_kubesphere_values(){
    scp root@master1:/etc/kubernetes/pki/* /etc/kubernetes/pki
    local kubernetes_token=$(kubectl -n kubesphere-system get secrets $(kubectl -n kubesphere-system get sa kubesphere -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d)
    replace_kv /opt/kubesphere/kubesphere/values.yaml kubernetes_token SHOULD_BE_REPLACED ${kubernetes_token}
    local kubernetes_ca_crt=$(cat /etc/kubernetes/pki/ca.crt | base64 | tr -d "\n")
    replace_kv /opt/kubesphere/kubesphere/values.yaml kubernetes_ca_crt SHOULD_BE_REPLACED ${kubernetes_ca_crt}
    local kubernetes_ca_key=$(cat /etc/kubernetes/pki/ca.key | base64 | tr -d "\n")
    replace_kv /opt/kubesphere/kubesphere/values.yaml kubernetes_ca_key SHOULD_BE_REPLACED ${kubernetes_ca_key}
    local kubernetes_front_proxy_client_crt=$(cat /etc/kubernetes/pki/front-proxy-client.crt | base64 | tr -d "\n")
    replace_kv /opt/kubesphere/kubesphere/values.yaml kubernetes_front_proxy_client_crt SHOULD_BE_REPLACED ${kubernetes_front_proxy_client_crt}
    local kubernetes_front_proxy_client_key=$(cat /etc/kubernetes/pki/front-proxy-client.key | base64 | tr -d "\n")
    replace_kv /opt/kubesphere/kubesphere/values.yaml kubernetes_front_proxy_client_key SHOULD_BE_REPLACED ${kubernetes_front_proxy_client_key}
}

function install_kubesphere(){
    if [ ! -f "/etc/kubernetes/pki/ca.crt" ] || [ ! -f "/etc/kubernetes/pki/ca.key" ] || 
    [ ! -f "/etc/kubernetes/pki/front-proxy-client.crt" ] || [ ! -f "/etc/kubernetes/pki/front-proxy-client.key" ]
    then
        echo $(date "+%Y-%m-%d %H:%M:%S") "install_kubesphere: scp cert"
        scp master1:/etc/kubernetes/pki/* /etc/kubernetes/pki/
    fi
    echo $(date "+%Y-%m-%d %H:%M:%S") "install_kubesphere: install kubesphere"
    pushd /opt/kubesphere/kubesphere
    retry ansible-playbook -i host-example.ini kubesphere-only.yaml -b
    popd
    echo $(date "+%Y-%m-%d %H:%M:%S") "install_kubesphere: create ks console svc"
    kubectl apply -f /opt/kubernetes/k8s/kubesphere/ks-console/ks-console-svc.yaml
    if [ "${CLUSTER_ELK_ID}" != "null" ]
    then
        echo $(date "+%Y-%m-%d %H:%M:%S") "install_kubesphere: create external elk svc"
        kubectl apply -f /opt/kubernetes/k8s/kubesphere/logging/external-elk-svc.yaml
    fi
}

function get_loadbalancer_ip(){
    lb_ip=`cat /etc/kubernetes/loadbalancer_ip`
    echo "${lb_ip}"
}

function replace_kubeadm_config_lb_ip(){
    lb_ip=`cat /etc/kubernetes/loadbalancer_ip`
    replace_kv /etc/kubernetes/kubeadm-config.yaml controlPlaneEndpoint SHOULD_BE_REPLACED $(echo ${lb_ip})
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
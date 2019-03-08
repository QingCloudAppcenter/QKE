#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")
KUBEADM_CONFIG_PATH="/data/kubernetes/kubeadm-config.yaml"
NODE_INIT_LOCK="/data/kubernetes/init.lock"
KUBE_LOCAL_CONF="/data/kubernetes/local.conf"
ORIGINAL_DIR=("/var/lib/docker" "/root/.docker"
"/var/lib/etcd" "/var/lib/kubelet" 
"/etc/kubernetes" "/root/.kube")
DATA_DIR=("/data/var/lib/docker" "/data/root/.docker"
"/data/var/lib/etcd" "/data/var/lib/kubelet"
"/data/kubernetes" "/data/root/.kube")
source "/data/env.sh"
source "${K8S_HOME}/version"

#set -o errexit
set -o nounset
set -o pipefail

function retry {
  local n=1
  local max=20
  local delay=6
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
            rm ${ORIGINAL_DIR[$i]}
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
    make_dir
    for i in "${!ORIGINAL_DIR[@]}"
    do
        if [ -d ${ORIGINAL_DIR[$i]} ] && [ ! -L ${ORIGINAL_DIR[$i]} ]
        then
            mv ${ORIGINAL_DIR[$i]} $(dirname ${DATA_DIR[$i]})
            ln -s ${DATA_DIR[$i]} ${ORIGINAL_DIR[$i]}
        fi
    done
}

function upgrade_docker(){
    #clear old aufs
    rm -rf /data/var/lib/docker/aufs
    rm -rf /data/var/lib/docker/image
    #copy overlays2
    mv /var/lib/docker/image /data/var/lib/docker/
    mv /var/lib/docker/overlay2 /data/var/lib/docker/
    rm -rf /var/lib/docker
    ln -s /data/var/lib/docker /var/lib/docker
    ln -s /data/var/lib/kubelet /var/lib/kubelet
    return 0
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

function join_node(){
    if [ -f "${NODE_INIT_LOCK}" ]; then
        echo "node has bean inited."
        return
    fi

    local init_token=`cat /data/kubernetes/init_token.metad`
    while [ -z "${init_token}" ]
    do
        echo "sleep for wait init_token for 2 second"
        sleep 2
        init_token=`cat /data/kubernetes/init_token.metad`
    done

    echo "Token: ${init_token}"
    retry ${init_token}

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
    kubectl apply -f /opt/kubernetes/k8s/addons/qingcloud-csi/csi-sc-capacity.yaml
}

function install_coredns(){
    kubeadm alpha phase addon coredns
    kubectl apply -f /opt/kubernetes/k8s/addons/coredns/coredns-deploy.yaml
}

function install_tiller(){
    kubectl apply -f /opt/kubernetes/k8s/addons/tiller/tiller-sa.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/tiller/tiller-deploy.yaml
    kubectl apply -f /opt/kubernetes/k8s/addons/tiller/tiller-svc.yaml
}
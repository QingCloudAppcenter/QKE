#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "/data/kubernetes/env.sh"
source "${K8S_HOME}/version"

#set -o errexit
set -o nounset
set -o pipefail

function retry {
  local n=1
  local max=5
  local delay=5
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

function ensure_dir(){
    if [ ! -d /root/.kube ]; then
        mkdir /root/.kube
    fi
    if [ ! -d /data/kubernetes ]; then
        mkdir -p /data/kubernetes
    fi
    if [ ! -d /data/kubernetes/hostnic ]; then
        mkdir -p /data/kubernetes/hostnic
    fi
    if [ ! -d /data/kubernetes/calico ]; then
        mkdir -p /data/kubernetes/calico
    fi
    if [ ! -L /etc/kubernetes ]; then
      ln -s /data/kubernetes /etc/kubernetes
    fi
}

function link_dir(){
    # Mkdir
    mkdir -p /data/var/lib
    mkdir -p /data/var/log
    mkdir -p /data/etc
    mkdir -p /data/root
    # Docker
    if [ -d "/var/lib/docker" ] && [ ! -L "/var/lib/docker" ]
    then
        mv /var/lib/docker /data/var/lib/
        ln -s /data/var/lib/docker /var/lib/docker
    fi
    # Kubelet
    if [ -d "/var/lib/kubelet" ] && [ ! -L "/var/lib/kubelet" ]
    then
        mv /var/lib/kubelet /data/var/lib/
        ln -s /data/var/lib/kubelet /var/lib/kubelet
    fi
    # Kubernetes
    if [ -d "/etc/kubernetes" ] && [ ! -L "/etc/kubernetes" ]
    then
        mv /etc/kubernetes /data/etc/
        ln -s /data/etc/kubernetes /etc/kubernetes
    fi
    ln -fs /root/.docker /data/root/.docker
    # Etcd
    if [ -d "/var/lib/etcd" ] && [ ! -L "/var/lib/etcd" ]
    then
        mv /var/lib/etcd /data/var
        ln -s /data/var/lib/etcd /var/lib/etcd
    fi
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

function copy_access_key(){
    echo "root:k8s" |chpasswd
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    mv /root/.ssh/authorized_keys /data/root
    ln -fs /data/authorized_keys /root/.ssh/authorized_keys
    systemctl restart ssh
}
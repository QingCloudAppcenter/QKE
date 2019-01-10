#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname $(dirname $(dirname "${SCRIPTPATH}")))

source "/data/kubernetes/env.sh"
source "${K8S_HOME}/version"

#set -o errexit
set -o nounset
set -o pipefail

NODE_INIT_LOCK="/data/kubernetes/init.lock"

function join_by {
    local IFS="$1"
    shift
    echo "$*"
}

function fail {
  echo $1 >&2
  exit 1
}

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

function long_retry {
  local n=1
  local max=10
  local delay=20
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

timestamp() {
  date +"%s"
}

function mykubectl(){
    kubectl --kubeconfig='/root/.kube/config' $*
}

function ensure_es(){
    if [ "${LOG_COUNT}" == "0" ] && [ "${ES_HOST:-}" == "" ] && [ "${ES_SERVER:-}" == ""  ]; then
        exit 101
    fi
    if [ "${LOG_COUNT}" == "0" ] && [ "${ES_HOST:-}" != "" ]; then
        loop=60
        while [ "$loop" -gt 0 ]
        do
          if timeout 2 bash -c "</dev/tcp/${ES_HOST:-}/${ES_PORT:-}"
          then
          break
          else
            sleep 5s
            loop=$[loop-10]
          fi
        done
        if [ "$loop" -eq 0 ]; then
          exit 102
        fi
    fi
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
    if [ ! -d /data/es ]; then
        mkdir -p /data/es
    fi
    if [ ! -L /etc/kubernetes ]; then
      ln -s /data/kubernetes /etc/kubernetes
    fi
}

function get_or_gen_init_token(){
    local init_token=""
    if [ -f "/data/kubernetes/init_token" ]; then
      init_token=$(cat /data/kubernetes/init_token)
    fi
    if [ -z  ${init_token}  ]; then
      init_token=$(kubeadm token generate)
      echo ${init_token} >/data/kubernetes/init_token
    fi
    echo ${init_token}
}

function replace_vars(){
    local from=$1
    local to=$2
    echo "process ${from} to ${to}"
    local prefix=$(timestamp)
    local name=$(basename ${from})
    local tmpfile="/tmp/${prefix}-${name}"
    sed 's/${HYPERKUBE_VERSION}/'"${HYPERKUBE_VERSION}"'/g' ${from} > ${tmpfile}
    sed -i 's/${KUBE_LOG_LEVEL}/'"${ENV_KUBE_LOG_LEVEL}"'/g' ${tmpfile}
    sed -i 's/${HOST_IP}/'"${HOST_IP}"'/g' ${tmpfile}
    sed -i 's/${MASTER_IP}/'"${MASTER_IP}"'/g' ${tmpfile}
    if [ "${to}" == "/data/kubernetes/manifests/kube-apiserver.yaml" ]
    then
        sed -i 's/${CLUSTER_PORT_RANGE}/'"${ENV_CLUSTER_PORT_RANGE:-}"'/g' ${tmpfile}
        if [ "${ETCD_CLUSTER:-}" != "" ]
        then
          sed -i 's/${ETCD_SERVERS}/'"${ETCD_CLUSTER:-}"'/g' ${tmpfile}
          sed -i 's/${CLUSTER_ID}/'"${CLUSTER_ID:-}"'/g' ${tmpfile}
        else
          sed -i 's/${ETCD_SERVERS}/'"http:\/\/127.0.0.1:2379"'/g' ${tmpfile}
          sed -i '/${CLUSTER_ID}/d' ${tmpfile}
       fi
    fi

    if [ "${to}" == "/data/kubernetes/addons/calico/calico-cm.yaml" ]
    then
        if [ "${ETCD_CLUSTER:-}" != "" ]
        then
          sed -i 's/${ETCD_SERVERS}/'"${ETCD_CLUSTER:-}"'/g' ${tmpfile}
        else
          sed -i 's/${ETCD_SERVERS}/'"http:\/\/${MASTER_IP}:2379"'/g' ${tmpfile}
        fi
    fi
          

    if [ "${LOG_COUNT}" != "0" ] && [ "${to}" == "/data/kubernetes/addons/monitor/es-controller.yaml" ]
    then
        sed -i 's/replicas:\s./replicas: '"${LOG_COUNT}"'/g' ${tmpfile}
    fi
    if [ "${LOG_COUNT}" == "0" ] && [ "${ES_HOST:-}" != "" ] 
    then
        if [ "${to}" == "/data/kubernetes/addons/monitor/fluentbit-ds.yaml" ] || [ "${to}" == "/data/kubernetes/addons/monitor/heapster-deployment.yaml" ] || [ "${to}" == "/data/kubernetes/addons/monitor/kibana-deployment.yaml" ]
        then
          sed -i 's/elasticsearch-logging/'"${ES_HOST:-}"'/g' ${tmpfile}
          sed -i 's/9200/'"${ES_PORT:-}"'/g' ${tmpfile}
          sed -i 's/role: log/'"role: node"'/g' ${tmpfile}
        fi
        if [ "${to}" == "/data/kubernetes/addons/monitor/es-statefulset.yaml" ]
        then
          sed -i 's/role: log/'"role: node"'/g' ${tmpfile}
        fi
    fi
    if [ -f ${to} ]
    then
        diff ${tmpfile} ${to} >> /dev/null
        if [ "$?" -ne 0 ]
        then
            cp ${tmpfile} ${to}
            echo "${to} update"
        else
            echo "${to} in sync"
        fi
    else
        cp ${tmpfile} ${to}
        echo "${to} create"
    fi

    rm ${tmpfile}
}

function update_k8s_manifests(){
    echo "echo update k8s manifests"
    mkdir /data/kubernetes/manifests/ || rm -rf /data/kubernetes/manifests/*
    mkdir /data/kubernetes/addons/ || rm -rf /data/kubernetes/addons/*
    process_manifests
    process_addons
}

function process_manifests(){
    mkdir -p /data/kubernetes/manifests/
    for f in ${K8S_HOME}/k8s/manifests/*; do
        name=$(basename ${f})
        replace_vars ${f} /data/kubernetes/manifests/${name}
    done
}

function process_addons(){
    mkdir -p /data/kubernetes/addons/

    for addon in ${K8S_HOME}/k8s/addons/*; do
        addon_name=$(basename $addon)
        mkdir -p /data/kubernetes/addons/${addon_name}
        for f in ${addon}/*; do
            name=$(basename ${f})
            replace_vars ${f} /data/kubernetes/addons/${addon_name}/${name}
        done
    done

    init_istio
    init_helm
    init_openpitrix
    init_kubesphere
}

function scale_es(){
    retry mykubectl scale --replicas=$1 statefulsets/elasticsearch-logging-v1 -n kube-system
}

function join_node(){
    ensure_dir
    if [ -f "${NODE_INIT_LOCK}" ]; then
        echo "node has bean inited."
        return
    fi

    local init_token=`cat /data/kubernetes/init_token.metad`
    while [ -z ${init_token} ]
    do
        echo "sleep for wait init_token for 2 second"
        sleep 2
        init_token=`cat /data/kubernetes/init_token.metad`
    done

    echo "master ip: ${MASTER_IP} init_token: ${init_token}"

    retry kubeadm join ${MASTER_IP}:6443 --token ${init_token} --skip-preflight-checks --discovery-token-unsafe-skip-ca-verification

    touch ${NODE_INIT_LOCK}
}

function node_ready(){
    status=`mykubectl get nodes |grep ${HOST_INSTANCE_ID}|awk '{print $2}'`
    echo "${HOST_INSTANCE_ID} status is ${status}"
    if [ "${status}" == "Ready" ];then
        return 0
    else
        return 1
    fi
}
function patch_cidr() {
    if [ "${ENV_NETWORK_PLUGINS}" == "flannel" ]; then
        long_retry node_ready
        echo "patch cidr config to node"
        mykubectl patch node ${HOST_INSTANCE_ID} -p '{"spec":{"podCIDR":"10.244.'${CIDR_SUBNET}'.0/24"}}'
    fi
}
function patch_flannel() {
    if [ "${ENV_NETWORK_PLUGINS}" == "flannel" ]; then
        ifconfig cni0 promisc
    fi
}

function wait_kubelet(){
    local isactive=`systemctl is-active kubelet`
    while [ "${isactive}" != "active" ]
    do
        echo "kubelet is ${isactive}, waiting 2 seconds to be active."
        sleep 2
        isactive=`systemctl is-active kubelet`
    done
}

function wait_apiserver(){
    while ! curl --output /dev/null --silent --fail http://localhost:8080/healthz;
    do
        echo "waiting k8s api server" && sleep 2
    done;
}

function train_master(){
    retry kubeadm alpha phase mark-master ${MASTER_INSTANCE_ID}
}

function train_node(){
    if [ "${HOST_ROLE}" == "log" ]
    then
        retry mykubectl taint nodes ${HOST_INSTANCE_ID} --overwrite dedicated=log:NoSchedule
    fi
    #if [ "${HOST_ROLE}" == "ssd_node" ]
    #then
    #    retry mykubectl taint nodes ${HOST_INSTANCE_ID} --overwrite dedicated=ssd:NoSchedule
    #fi
}

function cordon_all(){
    for node in $(mykubectl get nodes --no-headers=true -o custom-columns=name:.metadata.name)
    do
        mykubectl cordon $node
    done
}

function cordon_node(){
    mykubectl cordon ${HOST_INSTANCE_ID}
    return $?
}

function uncordon_all(){
    for node in $(mykubectl get nodes --no-headers=true -o custom-columns=name:.metadata.name)
    do
        mykubectl uncordon $node
    done
}

function clean_addons(){
    echo "stop addons-manager" && rm /data/kubernetes/manifests/kube-addon-manager.yaml && mykubectl delete --ignore-not-found=true "pods/kube-addon-manager-${MASTER_INSTANCE_ID}" -n kube-system
    mykubectl delete --timeout=60s --force --now -R -f /data/kubernetes/addons/
    echo "clean addons" && rm -rf /data/kubernetes/addons
}

function clean_static_pod(){
    echo "clean static pod" && rm -rf /data/kubernetes/manifests
}

function drain_node(){
    mykubectl drain --delete-local-data=true --ignore-daemonsets=true --force $1
    return $?
}

function link_dynamic_dir(){
    if [ ! -d "/data/var" ]
    then
        mkdir -p /data/var && mkdir /data/var/lib && mkdir /data/var/log && mkdir /data/var/log/qingcloud-flex-volume-controller-manager && mkdir /data/var/log/qingcloud-flex-volume
    fi
    if [ -d /var/lib/docker ] && [ ! -L /var/lib/docker ]
    then
        mv /var/lib/docker /data/var/lib/
        ln -s /data/var/lib/docker /var/lib/docker
    fi
    if [ ! -d "/data/var/lib/kubelet" ]
    then
        mkdir /data/var/lib/kubelet && ln -s /data/var/lib/kubelet /var/lib/kubelet
    fi
    if [ ! -d "/data/var/run/kubernetes" ]
    then
        mkdir -p /data/var/run/kubernetes && ln -s /data/var/run/kubernetes /var/run/kubernetes
    fi
    ln -fs /root/.docker /data/var/lib/kubelet/.docker
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

function docker_restart () {
  retry systemctl restart docker
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

function update_fluent_config(){
    if [ "${HOST_ROLE}" == "master" ]
    then
        mykubectl create configmap --dry-run -o yaml fluent-bit-extend -n kube-system --from-file /etc/kubernetes/fluentbit/extend.conf | mykubectl replace -n kube-system -f -
        #force rolling update
        local date=$(date +%s)
        sed -i 's/qingcloud\.com\/update-time:.*/qingcloud\.com\/update-time: "'${date}'"/g' ${K8S_HOME}/k8s/addons/monitor/fluentbit-ds.yaml
        cp ${K8S_HOME}/k8s/addons/monitor/fluentbit-ds.yaml /data/kubernetes/addons/monitor/fluentbit-ds.yaml
        mykubectl apply -f /data/kubernetes/addons/monitor/fluentbit-ds.yaml
    fi
}

function update_hostnic_config(){
    if [ "${HOST_ROLE}" == "master" ]
    then
      curl --output /dev/null --silent --fail http://localhost:8080/healthz;
      retcode=$?
      if [ $retcode -eq 0 ]
      then
        cp ${K8S_HOME}/k8s/addons/hostnic/qingcloud-hostnic-cni.yaml /data/kubernetes/addons/hostnic/qingcloud-hostnic-cni.yaml
        mykubectl apply -f /data/kubernetes/addons/hostnic/qingcloud-hostnic-cni.yaml
      fi
    fi
}

function init_istio(){
    if [ "${HOST_ROLE}" == "master" ] && [ "${ENV_ENABLE_ISTIO}" == "yes" ]
    then
      if mykubectl get svc istio-pilot -n istio-system > /dev/null 2>&1; then
        echo "istio has been deployed"
      else
        mykubectl apply -f /opt/istio-0.8.0/install/kubernetes/istio-demo.yaml
      fi
    fi
}

function init_helm(){
    if [ "${HOST_ROLE}" == "master" ]
    then
      if mykubectl get deploy tiller-deploy -n kube-system > /dev/null 2>&1; then
        echo "helm has been deployed"
      else
        mykubectl apply -f /opt/kubernetes/k8s/services/helm/helm.yaml
      fi
    fi
}

function upgrade_helm(){
    if [ "${HOST_ROLE}" == "master" ]
    then
      helm init --upgrade
    fi
}

function init_helm_client(){
    helm init --stable-repo-url https://helm-chart-repo.pek3a.qingstor.com/kubernetes-charts/ --client-only --home /root/.helm
}

function init_openpitrix() {
    mykubectl get ns openpitrix-system
    retcode=$?
    if [ $retcode != 0 ]; then
        cd /opt/openpitrix-v0.1.6-kubernetes/kubernetes/scripts
        ./deploy-k8s.sh -n openpitrix-system -v v0.1.6 -b -d
    fi
}

function init_kubesphere() {
    echo "deploy kubesphere"
    mykubectl get ns kubesphere-system
    retcode=$?
    if [ $retcode != 0 ]; then
        mykubectl create namespace kubesphere-system
        mykubectl apply -f /opt/KubeInstaller-express-1.0.0-alpha/kubesphere-controls-system.yaml
        mykubectl -n kubesphere-system create secret generic front-proxy-client --from-file=front-proxy-client.crt=/etc/kubernetes/pki/front-proxy-client.crt --from-file=front-proxy-client.key=/etc/kubernetes/pki/front-proxy-client.key
        mykubectl create configmap ks-console-config --from-file=local_config.alpha.yaml=/opt/KubeInstaller-express-1.0.0-alpha/ks-console/ks-console-config.ini -n kubesphere-system
        mykubectl apply -f /opt/KubeInstaller-express-1.0.0-alpha/ks-console/.
        mykubectl apply -f /opt/KubeInstaller-express-1.0.0-alpha/ks-account/.
        CA_KEY=`base64 -w 0 /data/kubernetes/pki/ca.key`
        CA_CRT=`base64 -w 0 /data/kubernetes/pki/ca.crt`
        sed -i 's/${KS_CA_CRT}/'"${CA_CRT}"'/g' /opt/KubeInstaller-express-1.0.0-alpha/ks-apiserver/kubesphere-secret.yaml
        sed -i 's/${KS_CA_KEY}/'"${CA_KEY}"'/g' /opt/KubeInstaller-express-1.0.0-alpha/ks-apiserver/kubesphere-secret.yaml
        sed -i 's/${MASTER_IP}/'"${MASTER_IP}"'/g' /opt/KubeInstaller-express-1.0.0-alpha/ks-apiserver/ks-apiserver-deploy.yaml
        mykubectl apply -f /opt/KubeInstaller-express-1.0.0-alpha/ks-apiserver/.
        mykubectl create configmap admin --from-file=config=/etc/kubernetes/admin.conf -n kubesphere-controls-system
    fi
}

function get_node_status(){
    local status=$(mykubectl get nodes/${HOST_INSTANCE_ID} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    echo ${status}
}

function clean_heapster140(){
    if mykubectl get deploy heapster-v1.4.0 -n kube-system > /dev/null 2>&1; then
      mykubectl delete deploy heapster-v1.4.0 -n kube-system
    else
      echo "try to clean heapster 1.4.0, but no old heapster deployment existed"
    fi
}

function kubelet_active(){
  retry systemctl is-active kubelet >/dev/null 2>&1
}

function docker_active(){
  retry systemctl is-active docker >/dev/null 2>&1
}

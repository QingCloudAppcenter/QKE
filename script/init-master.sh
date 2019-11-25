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
${K8S_HOME}/script/check-fs.sh
${K8S_HOME}/script/check-env.sh
source "${K8S_HOME}/script/common.sh"
source "${K8S_HOME}/script/loadbalancer-manager.sh"
log "===start init master===" 
log "link dir" 
link_dir
log "swapoff" 
swapoff -a
log "touch lb ip file" 
touch /etc/kubernetes/loadbalancer_ip
log "systemctl restart docker" 
systemctl restart docker
log "is docker active" 
is_systemd_active docker
log "docker active" 

if [ ${ENV_MASTER_COUNT} -gt 1 ]
then
    log "replace kubeadm config lb ip" 
    replace_kubeadm_config_lb_ip
    log "replace kubeadm eip lb ip"
    replace_kubeadm_eip_lb_ip
    log "replace hosts lb ip" 
    replace_hosts_lb_ip
fi

log "is kubeadm config file exist" 
if [ -f "${KUBEADM_CONFIG_PATH}" ]
then
    cat ${KUBEADM_CONFIG_PATH}
fi

if [ "${CLUSTER_ETCD_ID}" == "null" ]
then
    log "start etcd" 
    systemctl daemon-reload
    retry systemctl start etcd
    is_systemd_active etcd
    log "finish start etcd" 
fi

if [ "${HOST_SID}" == "1" ]
then
    # Create Common Cert Files
    log "create ca files" 
    kubeadm init phase certs ca --config ${KUBEADM_CONFIG_PATH} 
    kubeadm init phase certs sa
    kubeadm init phase certs front-proxy-ca --config ${KUBEADM_CONFIG_PATH}
    # Copy Cert to Other Master
    log "copy ca to other masters" 
    cat << EOF > /etc/kubernetes/certificate_files.txt
/etc/kubernetes/pki/ca.crt
/etc/kubernetes/pki/ca.key
/etc/kubernetes/pki/sa.key
/etc/kubernetes/pki/sa.pub
/etc/kubernetes/pki/front-proxy-ca.crt
/etc/kubernetes/pki/front-proxy-ca.key
EOF
    tar -czf /etc/kubernetes/control-plane-certificates.tar.gz -T /etc/kubernetes/certificate_files.txt
    for((i=2;i<=${ENV_MASTER_COUNT};i++));
    do
        scp /etc/kubernetes/control-plane-certificates.tar.gz root@$(eval echo '$'"MASTER_${i}_INSTANCE_ID"):/etc/kubernetes
    done
    log "finish copy ca to other masters" 
else
    # Get control plane cert files
    log "waiting for ca files" 
    while [ -z "/etc/kubernetes/control-plane-certificates.tar.gz" ]
    do
        log "sleep for wait cert files"
        sleep 2
    done
    log "finish receiving ca files"
    retry tar -xzf /etc/kubernetes/control-plane-certificates.tar.gz -C /etc/kubernetes/pki --strip-components 3
    log "finish extracting ca files"
fi

# Create Cert Files
log "start init certs"
kubeadm init phase certs apiserver --config ${KUBEADM_CONFIG_PATH} 
kubeadm init phase certs apiserver-kubelet-client --config ${KUBEADM_CONFIG_PATH}
kubeadm init phase certs front-proxy-client --config ${KUBEADM_CONFIG_PATH}
log "finish init certs"
# Write KubeConfig file to disk
log "start create kubeconfig"
kubeadm init phase kubeconfig all --config ${KUBEADM_CONFIG_PATH}
# Set Kubelet Args
# Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
# Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
# Restart the kubelet service 
log "set kubelet args"
kubeadm init phase kubelet-start --config ${KUBEADM_CONFIG_PATH}
# Write Static Pod manifest
log "write manifest"
kubeadm init phase control-plane all --config ${KUBEADM_CONFIG_PATH}

# Start Kubelet
log "restart kubelet"
systemctl daemon-reload
retry systemctl restart kubelet
is_systemd_active kubelet
log "finish restart kubelet"
log "wait for master started"
retry kubectl get nodes --kubeconfig ${KUBECONFIG}
log "master has been started"
log "create kubeconfig link"
ln -s ${KUBECONFIG} /root/.kube/config

if [ "${HOST_SID}" == "1" ]
then
    # storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
    log "upload kubeadm config"
    retry kubeadm init phase upload-config kubeadm --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    # Creating a ConfigMap "kubelet-config-1.13" in namespace kube-system with the configuration for the kubelets in the cluster
    log "upload kubelet config"
    retry kubeadm init phase upload-config kubelet --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    # Create Token
    log "Create Token"
    retry kubeadm init phase bootstrap-token --config ${KUBEADM_CONFIG_PATH} --kubeconfig ${KUBECONFIG}
    # Install Addons
    log "Install Kube-Proxy"
    retry install_kube_proxy
    # Install Network Plugin
    log "Install Network Plugin"
    retry install_network_plugin
    # Install Coredns
    log "Install Coredns"
    retry install_coredns
    # Install Storage Plugin
    log "Install CSI"
    retry install_csi
    # Install Tiller
    log "Install Tiller"
    retry install_tiller
fi

# Mark Master
log "Mark Master"
kubeadm init phase mark-control-plane --node-name ${HOST_INSTANCE_ID}
retry kubectl patch node ${HOST_INSTANCE_ID} -p '{"metadata":{"labels":{"role":"master"}}}'

touch ${PERMIT_RELOAD_LOCK}
chmod 400 ${PERMIT_RELOAD_LOCK}
log "===end init master==="
exit 0
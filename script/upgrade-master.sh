SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

# copy images
upgrade_k8s_image

# copy binary (kubelet, kubeadm, kubectl)
upgrade_binary

# copy scripts
upgrade_scripts

# copy confd template files
retry systemctl stop kubelet
upgrade_copy_confd
retry systemctl start kubelet
is_systemd_active kubelet

if [ "${HOST_SID}" == "1" ]
then
    upgrade_cloud_controller_manager

    install_network_plugin

    install_kube_proxy

    install_tiller
fi

# update images
upgrade_k8s_image
upgrade_overlay
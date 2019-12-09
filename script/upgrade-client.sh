SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

# copy binary (kubelet, kubeadm, kubectl)
upgrade_binary

# copy scripts
upgrade_scripts

# copy confd template files
upgrade_copy_confd

upgrade_csi
#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

CONFIG_FILES=(
    "/data/kubernetes/admin.conf"
    "/data/kubernetes/controller-manager.conf"
    "/data/kubernetes/scheduler.conf"
    "/data/kubernetes/kubelet.conf"
    )

CONFIG_SUB_CMD=(
    "admin"
    "controller-manager"
    "scheduler"
    "kubelet"
)

ONE_MONTH_TIMESTAMP=2592000

function is_needed_renew_config(){
    filename=$1
    tmp_cert_file="tmp.cert"
    cat ${filename} | shyaml get-value users.0.user.client-certificate-data | base64 -d > ${tmp_cert_file}
    expire_date=$(openssl x509 -in ${tmp_cert_file} -noout -enddate  | sed "s/notAfter=//g")
    expire_ts=$(date -d "${expire_date}" +%s)
    current_ts=$(date '+%s')
    difference_ts=$(expr $expire_ts - $current_ts)
    if [ ${difference_ts} -lt ${ONE_MONTH_TIMESTAMP} ]
    then
        return 0
    else
        return 1
    fi
}

function renew_config_files(){
    for i in "${!CONFIG_FILES[@]}"
    do
        if [ ! -f ${CONFIG_FILES[$i]} ]
        then
            kubeadm init phase kubeconfig ${CONFIG_SUB_CMD[$i]} --config ${KUBEADM_CONFIG_PATH}
        fi
        is_needed_renew_config ${CONFIG_FILES[$i]}
        if [ $? -eq 0 ]
        then
            rm -rf ${CONFIG_FILES[$i]}
            kubeadm init phase kubeconfig ${CONFIG_SUB_CMD[$i]} --config ${KUBEADM_CONFIG_PATH}
        fi
    done
}

if [ "${HOST_ROLE}" == "master" ]
then
    renew_config_files
fi
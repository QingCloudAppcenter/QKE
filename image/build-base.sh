#!/usr/bin/env bash

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

set -o errexit
set -o nounset
set -o pipefail

# update docker
${K8S_HOME}/image/update-docker.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update docker failed!"
    exit 255
fi

# update kubelet, kubeadm, kubectl
${K8S_HOME}/image/update-kubernetes.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update kubelet, kubeadm, kubectl failed!"
    exit 255
fi

# update helm
${K8S_HOME}/image/update-helm.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update Helm failed!"
    exit 255
fi

# update util tools
${K8S_HOME}/image/update-pkg.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update util tools failed!"
    exit 255
fi

# update appcenter agent
${K8S_HOME}/image/update-qingcloud-agent.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update appcenter agent failed!"
    exit 255
fi

# update confd
${K8S_HOME}/image/update-confd.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update confd failed!"
    exit 255
fi

# update qingcloud cli
${K8S_HOME}/image/update-qingcloud-cli.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update QingCloud CLI failed!"
    exit 255
fi

# update sshd config
${K8S_HOME}/image/update-sshd-config.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update sshd config failed!"
    exit 255
fi

# update docker images
${K8S_HOME}/image/update-docker-images.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update docker images failed!"
    exit 255
fi

# update etcd
${K8S_HOME}/image/update-etcd.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update etcd failed!"
    exit 255
fi

# disable and stop process managed by systemd
${K8S_HOME}/image/update-systemd.sh
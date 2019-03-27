#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

if [ "${HOST_ROLE}" == "master" ]
then
    if [ "${HOST_SID}" == "1" ]
    then
        install_cloud_controller_manager
    fi
fi
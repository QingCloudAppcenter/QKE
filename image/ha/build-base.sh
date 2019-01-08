#!/usr/bin/env bash

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname $(dirname "${SCRIPTPATH}"))

set -o errexit
set -o nounset
set -o pipefail

# install docker
${K8S_HOME}/image/ha/install-docker.sh

# install kubelet, kubeadm, kubectl
${K8S_HOME}/image/ha/install-kubernetes.sh

# install util tools
${K8S_HOME}/image/ha/update-pkg.sh

# install appcenter agent
${K8S_HOME}/image/ha/update-qingcloud-agent.sh

# update confd
${K8S_HOME}/image/ha/update-confd.sh

# install qingcloud cli
${K8S_HOME}/image/ha/install-cli.sh
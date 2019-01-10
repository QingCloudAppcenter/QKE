#!/usr/bin/env bash

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname $(dirname $(dirname "${SCRIPTPATH}")))

set -o errexit
set -o nounset
set -o pipefail

# update docker
${K8S_HOME}/scripts/ha/build/update-docker.sh

# update kubelet, kubeadm, kubectl
${K8S_HOME}/scripts/ha/build/update-kubernetes.sh

# update util tools
${K8S_HOME}/scripts/ha/build/update-pkg.sh

# update appcenter agent
${K8S_HOME}/scripts/ha/build/update-qingcloud-agent.sh

# update confd
${K8S_HOME}/scripts/ha/build/update-confd.sh

# update qingcloud cli
${K8S_HOME}/scripts/ha/build/update-qingcloud-cli.sh

# update sshd config
${K8S_HOME}/scripts/ha/build/update-sshd-config.sh
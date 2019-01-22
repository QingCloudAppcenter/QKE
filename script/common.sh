#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname $(dirname $(dirname "${SCRIPTPATH}")))

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
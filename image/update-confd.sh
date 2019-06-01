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

echo "*************************"
echo "update confd"
echo "*************************"

rm -rf /etc/confd/conf.d/k8s
rm -rf /etc/confd/templates/k8s
mkdir -p /etc/confd
cp -r ${K8S_HOME}/confd/* /etc/confd/

if systemctl is-active confd > /dev/null
then
    systemctl restart confd
fi

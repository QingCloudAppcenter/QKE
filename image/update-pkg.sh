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

echo "*************************"
echo "update pkg"
echo "*************************"

sed -i 's/main/& universe/g' /etc/apt/sources.list

apt-get update

apt install python-pip -y

apt-get install -y ebtables socat jq apt-transport-https bash-completion ntp wget ca-certificates curl software-properties-common tree ipvsadm zip unzip bridge-utils

apt-get remove -y network-managerupda

DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

modprobe ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack_ipv4

sysctl net.bridge.bridge-nf-call-iptables=1

pip install shyaml ansible
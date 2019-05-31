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
echo "upgrade app agent"
echo "*************************"

cd /tmp
wget http://appcenter-docs.qingcloud.com/developer-guide/scripts/app-agent-linux-amd64.tar.gz
tar -zxvf app-agent-linux-amd64.tar.gz
cd app-agent-linux-amd64/
./install.sh

chmod +x /etc/init.d/confd

cd /tmp
rm -rf app-agent-linux-amd64/
rm app-agent-linux-amd64.tar.gz

echo "*************************"
echo "upgrade confd"
echo "*************************"

wget https://github.com/yunify/confd/releases/download/v0.13.12/confd-linux-amd64.tar.gz
tar -O -zxf confd-linux-amd64.tar.gz >/opt/qingcloud/app-agent/bin/confd
chmod +x /opt/qingcloud/app-agent/bin/confd
rm confd-linux-amd64.tar.gz

systemctl enable confd
systemctl disable confd
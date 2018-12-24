#!/bin/bash
echo "start installing some tools"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common kubectl
echo "source <(kubectl completion bash)" >> ~/.bashrc

echo "install agent"
wget -qO- http://appcenter-docs.qingcloud.com/developer-guide/scripts/app-agent-linux-amd64.tar.gz | tar -xvz
cd app-agent-linux-amd64
./install.sh
cd ../
rm -rf app-agent-linux-amd64
echo "DONE"
#/bin/bash

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common kubectl
echo "source <(kubectl completion bash)" >> ~/.bashrc
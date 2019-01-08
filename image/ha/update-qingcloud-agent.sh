#!/usr/bin/env bash

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
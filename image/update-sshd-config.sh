#!/usr/bin/env bash

echo "*************************"
echo "update sshd config"
echo "*************************"

sed -i 's/TCPKeepAlive yes/TCPKeepAlive no/g' /etc/ssh/sshd_config
if ! grep "ClientAliveInterval" /etc/ssh/sshd_config >/dev/null
then
    echo "ClientAliveInterval 120" >> /etc/ssh/sshd_config
fi
if ! grep "ClientAliveCountMax" /etc/ssh/sshd_config >/dev/null
then
    echo "ClientAliveCountMax 720" >> /etc/ssh/sshd_config
fi

systemctl restart ssh
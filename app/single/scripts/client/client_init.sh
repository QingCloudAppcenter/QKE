#!/bin/bash
function RUN(){
    mkdir ~/.kube
    echo "root:k8s" |chpasswd
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    systemctl restart ssh
}

RUN >>/tmp/client_init.log 2>&1
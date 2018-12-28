#!/bin/bash

TOKEN=`kubeadm token create --ttl 0`
SHA=`openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'`

ip=`curl http://metadata/self/host/ip`
adminconf=$(cat "/etc/kubernetes/admin.conf"|base64 -w 0)
JOINTOKEN="kubeadm join --token $TOKEN $ip:6443 --discovery-token-ca-cert-hash sha256:$SHA"
echo '{"join_cmd":"'$JOINTOKEN'","adminconf":"'${adminconf}'"}'

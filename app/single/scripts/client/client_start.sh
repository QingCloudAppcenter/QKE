#!/bin/bash

function RUN(){
    curl http://metadata/self/hosts/master | grep token | awk '{for(i=2;i<=NF;i++) printf $i""FS}' | jq -r .adminconf | base64 -d > ~/.kube/config
    kubectl --kubeconfig ~/.kube/config cluster-info
}

RUN >>/tmp/client_start.log 2>&1


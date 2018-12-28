#!/bin/bash

function RUN(){
    curl http://metadata/host/token | jq -r .adminconf | base64 -d > ~/.kube/config
    kubectl cluster-info
}

RUN >>/tmp/client_start.log 2>&1


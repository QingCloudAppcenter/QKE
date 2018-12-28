#!/bin/bash
set -e
function RUN(){
    swapoff -a
}

RUN >>/tmp/node_init.log 2>&1

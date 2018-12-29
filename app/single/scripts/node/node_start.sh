#!/bin/bash
function RUN(){
    join_cmd=`curl http://metadata/self/hosts/master | grep token | awk '{for(i=2;i<=NF;i++) printf $i""FS}' | jq -r .join_cmd`
    $join_cmd
}

RUN >>/tmp/node_start.log 2>&1

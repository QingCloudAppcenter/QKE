#!/bin/bash
function RUN(){
    join_cmd=`curl http://metadata/host/token | jq -r .join_cmd`
    $join_cmd
}

RUN >>/tmp/node_start.log 2>&1

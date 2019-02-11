#!/bin/bash
vxnet_id=vxnet-lddzg8e
route_id=rtr-gkubu96i
appversion=appv-tzssw6ay

function CliDoneOrDie(){
    ret_json=$1
    ret_code=$(echo $ret_json | jq -r '.ret_code')
    if [ $ret_code -ne 0 ]; then
        printf "Error in %s! pls check the response: \n%s\n" "$2" "$ret_code"
        exit 1
    fi
    if [ $3 != "" ]; then 
        echo $ret_json | jq -r "$3"
    fi 
}

function URLEncode(){
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
          *) printf "$c" | xxd -p -c1 | while read x;do printf "%%%s" "$x";done
        esac
    done
}

function Trim(){
    str=$1
    echo ${str//\"/}
}

function WaitUntilDoneOrTimeOut(){
    if [ $# -lt 2 ]; then
        printf "Please at least input two parameter\n"
        exit 1
    fi
    action=$1
    shift 1
    local timeout=60
    local t=0
    local ret_code=-1
    while true; do
       local ret_json=`bash -c "$*"`
       ret_code=` echo $ret_json| jq -r .ret_code`
       if [ $ret_code -eq 0 ]; then
          printf "%s succeed\n" "$action"
          break
       else
          printf "[Will try again]Error in %s! pls check the response: \n%s\n" "$action" "$ret_json"
          printf "Command is %s\n" "$*"
       fi
       let t=t+4
       sleep 4s
    done
    if [ $timeout -le $t ]; then
        printf "Error! Timeout wait for %s\n" "$action"
        exit 1
    fi
}

function DateString(){
    date '+%Y%m%d-%T'
}
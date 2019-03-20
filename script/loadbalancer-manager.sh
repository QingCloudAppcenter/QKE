#!/usr/bin/env bash
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")

source "${K8S_HOME}/script/common.sh"

# Get firewall id
# { 
#  "action": "DescribeSecurityGroupsResponse", 
#  "total_count": 1, 
#  "security_group_set": [
#    {
#      "vbc_isol_master": "", 
#      "is_applied": 1, 
#      "description": null, 
#      "tags": [], 
#      "controller": "self", 
#      "console_id": "qingcloud", 
#      "is_default": 0, 
#      "root_user_id": "usr-kylwuKxL", 
#      "create_time": "2019-03-18T01:55:14Z", 
#      "owner": "usr-kylwuKxL", 
#      "vbc_isol_enabled": 0, 
#      "security_group_name": "0318-0955", 
#      "resource_project_info": [], 
#      "security_group_id": "sg-7nhtxb0r", 
#      "group_type": ""
#    }
#  ], 
#  "ret_code": 0
# }
function get_firewall_id(){
    firewall_name=${1}
    ret_str=$(qingcloud iaas describe-security-groups -f /etc/qingcloud/client.yaml -W ${firewall_name})
    ret_firewall_name=$(echo ${ret_str} | jq -r ".security_group_set[0].security_group_name")
    ret_firewall_id=$(echo ${ret_str} | jq -r ".security_group_set[0].security_group_id")
    if [ "${firewall_name}" == "${ret_firewall_name}" ]
    then
        echo ${ret_firewall_id}
    else
        echo ""
    fi
}

function create_firewall(){
    firewall_name=${1}
    exist_id=$(get_firewall_id ${firewall_name})
    if [ "${exist_id}" != "" ]
    then
        return 0
    fi

    ret_str=$(qingcloud iaas create-security-group -f /etc/qingcloud/client.yaml -N ${firewall_name})
    ret_val=$(echo ${ret_str} | jq -r ".ret_code")
    if [ ${ret_val} -eq 0 ]
    then
        echo "succeed to create firewall"
        return 0
    else
        echo "failed to create firewall" ${ret_str}
        return ${ret_val}
    fi
}

# Add rule on firewall return json
# {
#  "action": "AddSecurityGroupRulesResponse", 
#  "security_group_rules": [
#    "sgr-0xj0ciyz"
#  ], 
#  "ret_code": 0
# }
function add_rule_on_firewall(){
    firewall_id=${1}
    rule='[{"security_group_rule_name":"apiserver","protocol":"tcp","priority":"0","action":"accept","val1":"6443","val2":"6443"}]'
    ret_str=$(qingcloud iaas add-security-group-rules -f /etc/qingcloud/client.yaml -s ${firewall_id} -r $rule)
    ret_val=$(echo ${ret_str} | jq -r ".ret_code")
    if [ ${ret_val} -eq 0 ]
    then
        echo "succeed to add rule on firewall"
        return 0
    else
        echo "failed to add rule on firewall" ${ret_str}
        return ${ret_val}
    fi
}

function create_loadbalancer(){
    loadbalancer_name=${1}
    vxnet=${2}
    firewall_id=${3}
    exist_id=$(get_loadbalancer_id ${loadbalancer_name})
    if [ "${exist_id}" != "" ]
    then
        return 0
    fi

    ret_str=$(qingcloud iaas create-loadbalancers -f /etc/qingcloud/client.yaml -N ${loadbalancer_name} -x ${vxnet} -s ${firewall_id})
    ret_val=$(echo ${ret_str} | jq -r ".ret_code")

    if [ ${ret_val} -eq 0 ]
    then
        echo "succeed to create loadbalancer"
        return 0
    else
        echo "failed to create loadbalancer" ${ret_str}
        return ${ret_val}
    fi
}

function get_loadbalancer_id(){
    loadbalancer_name=${1}
    ret_str=$(qingcloud iaas describe-loadbalancers -f /etc/qingcloud/client.yaml -W ${loadbalancer_name})
    cnt=$(echo ${ret_str}|jq -r ".loadbalancer_set[0:]" | jq length)
    for((i=0;i<${cnt};i++))
    do
        ret_loadbalancer_name=$(echo ${ret_str}| jq -r ".loadbalancer_set[${i}].loadbalancer_name")
        ret_loadbalancer_status=$(echo ${ret_str}| jq -r ".loadbalancer_set[${i}].status")
        if !([ "${ret_loadbalancer_status}" == "ceased" ] || [ "${ret_loadbalancer_status}" == "deleted" ]) && [ "${ret_loadbalancer_name}" == "${loadbalancer_name}" ]
        then
            ret_loadbalancer_id=$(echo ${ret_str}| jq -r ".loadbalancer_set[${i}].loadbalancer_id")
            echo ${ret_loadbalancer_id}
            return
        fi
    done
    echo ""
}

function get_loadbalancer_ip(){
    loadbalancer_id=${1}
    ret_str=$(qingcloud iaas describe-loadbalancers -f /etc/qingcloud/client.yaml -l ${loadbalancer_id})
    ret_val=$(echo ${ret_str} | jq -r ".ret_code")
    ret_loadbalancer_id=$(echo ${ret_str}| jq -r ".loadbalancer_set[0].loadbalancer_id")
    ret_loadbalancer_ip=$(echo ${ret_str}| jq -r ".loadbalancer_set[0].vxnet.private_ip")
    if [ "${ret_loadbalancer_id}" == "${loadbalancer_id}" ]
    then
        echo ${ret_loadbalancer_ip}
    else
        echo ""
    fi
}

# {
#  "action": "AddLoadBalancerListenersResponse", 
#  "loadbalancer_listeners": [
#    "lbl-b02v7jco"
#  ], 
#  "ret_code": 0
# }
function create_loadbalancer_listener(){
    loadbalancer_id=${1}
    rule="[{\"loadbalancer_listener_name\": \"apiserver\",\"listener_protocol\":\"tcp\",\"listener_port\":\"6443\",\"backend_protocol\":\"tcp\", \"balance_mode\": \"roundrobin\", \"forwardfor\": 0,\"healthy_check_method\": \"tcp\", \"healthy_check_option\":\"10|5|2|5\", \"session_sticky\": \"insert|3600\"}]"
    ret_str=$(qingcloud iaas add-loadbalancer-listeners -f /etc/qingcloud/client.yaml -l ${loadbalancer_id} -s "$rule")
    ret_val=$(echo ${ret_str} | jq -r ".ret_code")
    if [ "${ret_val}" == "0" ]
    then
        echo "succeed to apply loadbalancer"
        return 0
    else
        echo "failed to apply loadbalancer" ${ret_str}
        return ${ret_val}
    fi
}

# {
#   "action": "DescribeLoadBalancerListenersResponse", 
#   "total_count": 1, 
#   "loadbalancer_listener_set": [
#     {
#       "forwardfor": 0, 
#       "listener_option": 0, 
#       "healthy_check_option": "10|5|2|5", 
#       "backend_protocol": "tcp", 
#       "healthy_check_method": "tcp", 
#       "console_id": "qingcloud", 
#       "disabled": 0, 
#       "create_time": "2019-03-18T02:56:56Z", 
#       "waf_domain_policies": [], 
#       "owner": "usr-kylwuKxL", 
#       "balance_mode": "roundrobin", 
#       "listener_port_end": 0, 
#       "session_sticky": "insert|3600", 
#       "listener_protocol": "tcp", 
#       "server_certificate_id": [], 
#       "loadbalancer_listener_name": "apiserver", 
#       "controller": "self", 
#       "tunnel_timeout": 3600, 
#       "loadbalancer_listener_id": "lbl-b02v7jco", 
#       "listener_port": 6443, 
#       "root_user_id": "usr-kylwuKxL", 
#       "timeout": 50, 
#       "loadbalancer_id": "lb-hmaw5591"
#     }
#   ], 
#   "ret_code": 0
# }
function get_loadbalancer_listener_id(){
    loadbalancer_id=${1}
    ret_str=$(qingcloud iaas describe-loadbalancer-listeners -f /etc/qingcloud/client.yaml -l ${loadbalancer_id})
    ret_val=$(echo ${ret_str} | jq -r ".ret_code")
    ret_loadbalancer_listener_name=$(echo ${ret_str}| jq -r ".loadbalancer_listener_set[0].loadbalancer_listener_name")
    ret_loadbalancer_listener_id=$(echo ${ret_str}| jq -r ".loadbalancer_listener_set[0].loadbalancer_listener_id")
    if [ "${ret_loadbalancer_listener_name}" == "apiserver" ]
    then
        echo ${ret_loadbalancer_listener_id}
    else
        echo ""
    fi
}

function apply_loadbalancer(){
    loadbalancer_id=${1}
    ret_str=$(qingcloud iaas update-loadbalancers -f /etc/qingcloud/client.yaml -l ${loadbalancer_id})
    ret_val=$(echo ${ret_str} | jq -r ".ret_code")
    if [ ${ret_val} -eq 0 ]
    then
        echo "succeed to apply loadbalancer"
        return 0
    else
        echo "failed to apply loadbalancer" ${ret_str}
        return ${ret_val}
    fi
}

function is_loadbalancer_active(){
    loadbalancer_id=${1}
    ret_str=$(qingcloud iaas describe-loadbalancers -f /etc/qingcloud/client.yaml -l ${loadbalancer_id})
    ret_status=$(echo ${ret_str} | jq -r ".loadbalancer_set[0].status")
    if [ "${ret_status}" == "active" ]
    then
        return 0
    else
        return 1
    fi
}

function is_loadbalancer_ceased(){
    loadbalancer_id=${1}
    ret_str=$(qingcloud iaas describe-loadbalancers -f /etc/qingcloud/client.yaml -l ${loadbalancer_id})
    ret_status=$(echo ${ret_str} | jq -r ".loadbalancer_set[0].status")
    if [ "${ret_status}" == "ceased" ]
    then
        return 0
    else
        return 1
    fi
}

# Apply firewall
# {
#  "action": "ApplySecurityGroupResponse", 
#  "job_id": "j-j7m4fg0pd7n", 
#  "ret_code": 0
# }
function apply_firewall(){
    firewall_id=${1}
    ret_str=$(qingcloud iaas apply-security-group -f /etc/qingcloud/client.yaml -s ${firewall_id})
    ret_val=$(echo ${ret_str} | jq -r ".ret_code")
    if [ ${ret_val} -eq 0 ]
    then
        echo "succeed to apply firewall"
        return 0
    else
        echo "failed to apply firewall" ${ret_str}
        return ${ret_val}
    fi
}

# {
#   "action": "AddLoadBalancerBackendsResponse", 
#   "ret_code": 0, 
#   "loadbalancer_backends": [
#     "lbb-uwsuntby"
#   ]
# }
function add_loadbalancer_listener_backend(){
    loadbalancer_listener_id=${1}
    instance_id=${2}
    rule="[{\"resource_id\":\"${instance_id}\",\"port\":\"6443\",\"weight\":\"1\"}]"
    ret_str=$(qingcloud iaas add-loadbalancer-backends -f /etc/qingcloud/client.yaml -s ${loadbalancer_listener_id} -b "$rule")
    ret_val=$(echo ${ret_str} | jq -r ".ret_code")
    if [ ${ret_val} -eq 0 ]
    then
        echo "succeed to add loadbalancer listener backend"
        return 0
    else
        echo "failed to add loadbalancer listener backend" ${ret_str}
        return ${ret_val}
    fi
}

# {
#   "action": "DeleteLoadBalancersResponse", 
#   "loadbalancers": [
#     "lb-e1ewk5yr"
#   ], 
#   "job_id": "j-hwcnxvx1lht", 
#   "ret_code": 0
# }
function delete_loadbalancer(){
    loadbalancer_id=${1}
    ret_str=$(qingcloud iaas delete-loadbalancers -f /etc/qingcloud/client.yaml -l ${loadbalancer_id})
    ret_val=$(echo ${ret_str} |  jq -r ".ret_code")
    if [ ${ret_val} -eq 0 ]
    then
        echo "succeed to delete loadbalancer"
        return 0
    else
        echo "failed to delete loadbalancer" ${ret_str}
        return ${ret_val}
    fi  
}

function delete_firewall(){
    firewall_id=${1}
    ret_str=$(qingcloud iaas delete-security-groups -f /etc/qingcloud/client.yaml -s ${firewall_id})
    ret_val=$(echo ${ret_str} |  jq -r ".ret_code")
    if [ ${ret_val} -eq 0 ]
    then
        echo "succeed to delete firewall"
        return 0
    else
        echo "failed to delete firewall" ${ret_str}
        return ${ret_val}
    fi
}

#
#    firewall  ---------->    loadbalancer
#       ^                          ^
#       |                          |
# firewall rule            loadbalancer listener
#                                  ^
#                                  |
#                              instance
#
# Input:
#   param1: firewall and loadbalancer name
#   param2: vxnet id
function create_lb_and_firewall(){
    firewall_name=$1
    loadbalancer_name=$1
    vxnet=$2
    # Create firewall
    create_firewall ${firewall_name}
    if [ $? -ne 0 ]
    then
        return 101
    fi

    firewall_id=$(get_firewall_id ${firewall_name})
    if [ "${firewall_id}" == "" ]
    then
        echo "Failed to get firewall id"
        return 102
    fi

    add_rule_on_firewall ${firewall_id}
    if [ $? -ne 0 ]
    then
        echo "Failed to add rule on firewall"
        return 103
    fi

    apply_firewall ${firewall_id}
    if [ $? -ne 0 ]
    then
        echo "Failed to apply firewall"
        return 104
    fi

    # Create loadbalancer
    create_loadbalancer ${loadbalancer_name} ${vxnet} ${firewall_id}
    if [ $? -ne 0 ]
    then
        return 105
    fi

    loadbalancer_id=$(get_loadbalancer_id ${loadbalancer_name})
    for((i=1;i<=20;i++));
    do   
        sleep 5
        loadbalancer_id=$(get_loadbalancer_id ${loadbalancer_name})
        is_loadbalancer_active ${loadbalancer_id}
        if [ "$?" == "0" ]
        then
            break
        fi
        if [ "$i" == "20" ]
        then
            echo "create lb timeout"
            exit -1
        fi
    done
    echo lb_id ${loadbalancer_id}


    if [ "$loadbalancer_id" == "" ]
    then
        echo "Failed to get loadbalancer id"
        return 106
    fi

    create_loadbalancer_listener ${loadbalancer_id}
    if [ $? -ne 0 ]
    then
        echo "Failed to create loadbalancer listener"
        return 107
    fi

    loadbalancer_listener_id=$(get_loadbalancer_listener_id ${loadbalancer_id})
    if [ "$loadbalancer_listener_id" == "" ]
    then
        echo "Failed to get loadbalancer listener id"
        return 108
    fi

    add_loadbalancer_listener_backend ${loadbalancer_listener_id} $MASTER_1_INSTANCE_ID
    add_loadbalancer_listener_backend ${loadbalancer_listener_id} $MASTER_2_INSTANCE_ID
    add_loadbalancer_listener_backend ${loadbalancer_listener_id} $MASTER_3_INSTANCE_ID
    apply_loadbalancer ${loadbalancer_id}
    if [ $? -ne 0 ]
    then
        echo "Faile to apply loadbalancer"
        return 109
    fi
}

# Input: 
#   param1 lb name
function delete_lb_and_firewall(){
    obj_name=${1}
    loadbalancer_id=$(get_loadbalancer_id ${obj_name})
    if [ "${loadbalancer_id}" == "" ]
    then
        echo "Failed to get loadbalancer id"
        return 101
    fi

    delete_loadbalancer ${loadbalancer_id}
    if [ $? -ne 0 ]
    then
        echo "Failed to delete loadbalancer"
        return 102
    fi

    for((i=1;i<=20;i++));  
    do   
        sleep 5
        is_loadbalancer_ceased ${loadbalancer_id}
        if [ "$?" == "0" ]
        then
            break
        fi
        if [ "$i" == "20" ]
        then
            echo "delete lb timeout"
            exit -1
        fi
    done

    firewall_id=$(get_firewall_id ${obj_name})
    if [ "${firewall_id}" == "" ]
    then
        echo "Failed to get firewall id"
        return 103
    fi

    delete_firewall ${firewall_id}
    if [ $? -ne 0 ]
    then
        echo "Failed to delete firewall"
        return 104
    fi
}
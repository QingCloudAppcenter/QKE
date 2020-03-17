iaasRunCli() {
  local quiet=true; [ "$1" = "-q" ] && shift || quiet=false
  local result; result="$(/usr/local/bin/qingcloud iaas "$@" -f $QINGCLOUD_CONFIG)"
  test "$(echo "$result" | jq '.ret_code')" -eq 0 || {
    log "ERROR: failed to run iaas cli cmd '$@': '$result'."
    return $EC_IAAS_FAILED
  }
  $quiet || echo "$result"
}

iaasCreateSecurityGroup() {
  iaasRunCli create-security-group -N $1 | jq -r '.security_group_id'
}

iaasTagResource() {
  iaasRunCli -q attach-tags -p $1:$2:$3
}

iaasAddSecurityRules() {
  iaasRunCli -q add-security-group-rules -s $1 -r "$(yq r -j - <<< '
    - security_group_rule_name: apiserver
      protocol: tcp
      priority: "0"
      action: accept
      val1: "6443"
      zone: '$2'
  ')"
}

iaasApplySecurityGroup() {
  iaasRunCli -q apply-security-group -s $1
}

iaasCreateLb() {
  iaasRunCli create-loadbalancers --mode 1 -c 2 -N $1 -x $2 -s $3 | jq -er '.loadbalancer_id'
}

readonly IAAS_LBL_SCENE=11
iaasCreateListener() {
  iaasRunCli add-loadbalancer-listeners -l $1 -s "$(yq r -j - <<< '
    - loadbalancer_listener_name: apiserver
      listener_protocol: tcp
      listener_port: "6443"
      backend_protocol: tcp
      scene: '$IAAS_LBL_SCENE'
      forwardfor: 0
      session_sticky: insert|3600
  ')" | jq -er '.loadbalancer_listeners[0]'
}

iaasFixLbListener() {
  /opt/lbcli/current/lbcli -s=$1 -z=$2 -e=$IAAS_LBL_SCENE -f=$QINGCLOUD_CONFIG
}

iaasAddLbBackends() {
  iaasRunCli -q add-loadbalancer-backends -s $1 -b "$(echo -n ${@:2} | jq -Rsc 'split(" ") | map({
    resource_id: .,
    port: 6443,
    weight: 1
  })')"
}

iaasApplyLb() {
  iaasRunCli -q update-loadbalancers -l $1
}

iaasDescribeLb() {
  iaasRunCli describe-loadbalancers -l $1 | jq -er 'select(.loadbalancer_set[0].loadbalancer_id == "'$1'") | .loadbalancer_set[0].'$2''
}

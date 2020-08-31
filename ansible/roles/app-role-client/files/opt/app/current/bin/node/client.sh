APP_ERR_CODES="
EC_KS_INSTALL_POD_ERR
EC_KS_INSTALL_LOGS_ERR
EC_KS_INSTALL_FAILED
EC_KS_INSTALL_RUNNING
EC_KS_INSTALL_DONE_WITH_ERR
EC_IAAS_FAILED
EC_DRAIN_FAILED
EC_BELOW_MIN_WORKERS_COUNT
EC_UNCORDON_FAILED
EC_DO_NOT_DELETE_MASTERS
EC_OVERLAY_ERR
"

initNode() {
  _initNode
  mkdir -p /data/kubernetes
  ln -snf /data/kubernetes /etc/kubernetes
  mkdir -p /data/root/.kube
  ln -snf /data/root/.kube /root/.kube
  ln -snf $KUBE_CONFIG /root/.kube/config
  recover # in case deleted cluster recovered
}

initCluster() {
  _initCluster
  if ! $IS_JOINING; then
    local filePath=$APISERVER_LB_FILE && $IS_HA_CLUSTER || filePath=$KUBE_CONFIG
    retry 1200 1 0 test -s $filePath
    if $KS_ENABLED && ! $IS_UPGRADING_FROM_V1; then waitKsReady; fi
  fi
  setUpConfigs
}

upgrade() {
  if ! ${IS_UPGRADING_FROM_V1:-false} && ! ${IS_UPGRADING_FROM_V2:-false}; then
    log "No upgrading version detected,IS_UPGRADING_FROM_V1: $IS_UPGRADING_FROM_V1, IS_UPGRADING_FROM_V2: $IS_UPGRADING_FROM_V2"
    return $UPGRADE_VERSION_DETECTED_ERR
  fi
  execute start
  _initCluster
  if $IS_HA_CLUSTER && $IS_UPGRADING_FROM_V1; then echo -n "/$LB_IP_FROM_V1" > $APISERVER_LB_FILE; fi
  setUpConfigs
  if $KS_ENABLED; then
    waitKsUpgraded
  fi
}

recover() {
  setUpConfigs || log "looks like nothing to do. Ignoring ..."
}

setUpConfigs() {
  prepareFile $KUBE_CONFIG
  if $IS_HA_CLUSTER; then
    prepareFile $APISERVER_LB_FILE
    local lbIp; lbIp="$(awk -F/ '{print $2}' $APISERVER_LB_FILE | grep '^[0-9.]\+$')"
    if test -z "$lbIp"; then return; fi
    log --debug "updating lb ip with '$lbIp' ..."
    sed -ri "s/^.*(\sloadbalancer)/$lbIp\1/" /etc/hosts
  fi
}

prepareFile() {
  if test ! -s $1; then scp master1:$1 $1; fi
}

waitKsReady() {
  retry 1800 2 $EC_KS_INSTALL_DONE_WITH_ERR keepKsInstallerRunningTillDone
}

waitKsUpgraded() {
  retry 18000 2 $EC_KS_INSTALL_FAILED,$EC_KS_INSTALL_DONE_WITH_ERR checkKsInstallerDone
}

keepKsInstallerRunningTillDone() {
  checkKsInstallerDone || {
    local -r rc=$?
    if test $rc -eq $EC_KS_INSTALL_FAILED; then
      log "WARN: ks-installer failed. restarting it ..."
      runKubectl -n kubesphere-system rollout restart deploy ks-installer
    fi
    return $rc
  }
}

checkKsInstallerDone() {
  local podName; podName="$(getKsInstallerPodName)" || return $EC_KS_INSTALL_POD_ERR
  local output; output="$(runKubectl -n kubesphere-system logs --tail 90 $podName)" || return $EC_KS_INSTALL_LOGS_ERR
  if echo "$output" | grep "^PLAY RECAP **" -A1 | egrep -o "failed=[1-9]"; then return $EC_KS_INSTALL_FAILED; fi
  echo "$output" | grep -oF 'Welcome to KubeSphere!' || return $EC_KS_INSTALL_RUNNING
  echo "$output" | grep -oF "total: $KS_MODULES_COUNT     completed:$KS_MODULES_COUNT" || return $EC_KS_INSTALL_DONE_WITH_ERR
}

getKsInstallerPodName() {
  runKubectl -n kubesphere-system get pod -l app=ks-install --field-selector status.phase=Running -ojsonpath='{.items[0].metadata.name}' | grep ks-installer
}

runKubectl() {
  kubectl --kubeconfig $KUBE_CONFIG "$@"
}

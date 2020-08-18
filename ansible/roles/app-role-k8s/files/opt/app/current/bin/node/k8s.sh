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

generateDockerLayerLinks() {
  if [ ! -d "/data/var/lib/docker" ]; then
    mkdir -p /data/var/lib/docker/{overlay2,image}
    local layerName; for layerName in $(find /var/lib/docker/overlay2 -mindepth 1 -maxdepth 1 ! -name l); do
      ln -snf $layerName /data$layerName
    done
    rsync -aAX /var/lib/docker/overlay2/l /data/var/lib/docker/overlay2/
    rsync -aAX /var/lib/docker/image /data/var/lib/docker/
  fi
}

initNode() {
  _initNode
  generateDockerLayerLinks
  mkdir -p /data/kubernetes/{audit/{logs,policies},manifests} /data/var/lib/etcd
  ln -snf /data/kubernetes /etc/kubernetes
  local migratingPath; for migratingPath in root/{.docker,.kube,.config,.cache,.local,.helm} var/lib/kubelet; do
    if test -d /data/$migratingPath; then
      rm -rf /$migratingPath
    else
      mkdir -p /data/${migratingPath%/*}
      if test -d /$migratingPath; then
        test -L /$migratingPath || mv /$migratingPath /data/$migratingPath
      fi
      mkdir -p /data/$migratingPath
    fi
    ln -snf /data/$migratingPath /$migratingPath
  done
  test -f $DEFAULT_AUDIT_POLICY_FILE || cp /opt/app/current/conf/k8s/default-audit-policy-file.yaml $DEFAULT_AUDIT_POLICY_FILE
  ln -snf $KUBE_CONFIG /root/.kube/config
  chown -R etcd /data/var/lib/etcd
}

start() {
  log --debug "starting node ..."
  isNodeInitialized || initNode
  prepareKubeletEnv
  _start
  log --debug "started node."
}

initCluster() {
  log --debug "initializing cluster ..."
  _initCluster
  if isFirstMaster; then initFirstNode; else initOtherNode; fi
  annotateInstanceId
  rm -rf $JOIN_CMD_FILE
  log --debug "done initializing cluster!"
}

preScaleOut() {
  if isFirstMaster; then generateJoinCmd; fi
}

scaleOut() {
  isFirstMaster || return 0
  rm -rf $JOIN_CMD_FILE
  removeTokens
}

preScaleIn() {
  test -z "$LEAVING_MASTER_NODES" || return $EC_DO_NOT_DELETE_MASTERS
  isFirstMaster && test -n "$LEAVING_WORKER_NODES" || return 0
  test $(echo $STABLE_WORKER_NODES | wc -w) -ge 2 || return $EC_BELOW_MIN_WORKERS_COUNT
  local -r nodes="$(getNodeNames $LEAVING_WORKER_NODES)"
  local result; result="$( (runKubectl drain $nodes --ignore-daemonsets --timeout=2h && runKubectl delete no --timeout=10m $nodes) 2>&1)" || {
    log "ERROR: failed to remove nodes '$nodes' ($?): '$result'. Reverting changes ..."
    runKubectl uncordon $nodes || return $EC_UNCORDON_FAILED
    return $EC_DRAIN_FAILED
  }
}

scaleIn() {
  true
}

destroy() {
  kubeadm reset -f
  _destroy
}

getUpgradeOrder() {
  getColumns $INDEX_NODE_ID $STABLE_MASTER_NODES | paste -sd,
}

initControlPlane() {
  log --debug "init phase control-plane all"
  runKubeadm init phase control-plane ${@:-all}
  log --debug "init phase control-plane all end"
}

upgrade() {
  log "IS_UPGRADING_FROM_V1: $IS_UPGRADING_FROM_V1, IS_UPGRADING_FROM_V2: $IS_UPGRADING_FROM_V2"
  if ! ${IS_UPGRADING_FROM_V1:-false} && ! ${IS_UPGRADING_FROM_V2:-false}; then
    log "No upgrading version detected,IS_UPGRADING_FROM_V1: $IS_UPGRADING_FROM_V1, IS_UPGRADING_FROM_V2: $IS_UPGRADING_FROM_V2"
    return $UPGRADE_VERSION_DETECTED_ERR
  fi
  upgradeCniConf
  if ! isDev; then
    docker load -qi $UPGRADE_DIR/docker-images/k8s.tgz
    if $KS_ENABLED; then docker load -qi $UPGRADE_DIR/docker-images/ks.tgz; fi
    fixOverlays
  fi
  start
  if isMaster; then
    log --debug "I am master node"
    waitPreviousMastersUpgraded
    if ! $ETCD_PROVIDED && $IS_UPGRADING_FROM_V1; then restartSvc etcd; fi
    updateApiserverCerts
    log --debug "$KUBEADM_CONFIG contents: $(cat $KUBEADM_CONFIG)"
    initControlPlane
    log --debug "init phase kubelet-start"
    runKubeadm init phase kubelet-start
    log --debug "restart kubelet"
    restartSvc kubelet

    if isFirstMaster; then
      log --debug "distributeFile"
      local path; for path in $(ls /var/lib/kubelet/{config.yaml,kubeadm-flags.env}); do
        log --debug "$path:$(cat $path)"
        distributeFile $path $STABLE_WORKER_NODES
      done
      distributeKubeConfig

      if $IS_HA_CLUSTER && $IS_UPGRADING_FROM_V1; then
        local result lbId; result="$(fixLbListener)" && lbId=$result || log "WARN: failed to fix LB listener ($?): '$result'."
      fi
      waitAllNodesUpgradedAndReady
      runKubeadm init phase upload-config all
      # runKubectl annotate node $(getMyNodeName) kubeadm.alpha.kubernetes.io/cri-socket=/var/run/dockershim.sock
      # kubeadm upgrade node: unable to fetch the kubeadm-config ConfigMap: failed to getAPIEndpoint
      # runKubectlPatch cm kubeadm-config -p "$(yq n data.ClusterStatus -- "$(yq w /tmp/cm.yml data.ClusterStatus -- "$(for m in $STABLE_MASTER_NODES; do printf "%s:\n  advertiseAddress: %s\n  bindPort: 6443\n" $(echo $m | awk -F/ '{print $4, $7}'); done | yq p - apiEndpoints)")")"
      kubeadm upgrade apply v$K8S_VERSION --ignore-preflight-errors=CoreDNSUnsupportedPlugins -f
      applyKubeProxyLogLevel
      setUpNetwork
      setUpCloudControllerMgr
      setUpStorage
    fi
    log --debug "I am master node end"
  else
    log --debug "I am worker node"
    waitAllMasterNodesUpgradedAndReady
    if $IS_UPGRADING_FROM_V1; then retry 3600 1 0 test -s $KUBE_CONFIG; fi
    restartSvc kubelet
    log --debug "worker node end"
  fi
  if $IS_HA_CLUSTER && $IS_UPGRADING_FROM_V1; then
    saveLbFile $lbId/$LB_IP_FROM_V1
    updateLbIp
  fi
  if isFirstMaster && $KS_ENABLED; then
    launchKs
  fi
  _initCluster
}

checkSvc() {
  _checkSvc $@ || return $?
  local svcName=${1%%/*}
  if [ "$svcName" = "kubelet" ]; then [ "$(curl -s -m 5 localhost:10248/healthz)" = "ok" ]; fi
  if [ "$svcName" = "kube-certs.timer" ]; then checkCertDaysBeyond 25; fi
}

revive() {
  prepareKubeletEnv
  _revive
}

measure() {
  isClusterInitialized && isNodeInitialized || return 0
  local -r regex="$(sed 's/^\s*//g' <<< '
    kubelet_running_container_count{container_state="running"}
    kubelet_running_pod_count
  ' | paste -sd'|' | sed 's/^|/^(/; s/|$/)/')"
  runKubectl get -s https://localhost:10250 --raw /metrics --insecure-skip-tls-verify | egrep "$regex" | sed -r 's/\{[^}]+\}//g; s/ /: /g' | yq -j r -
}

reloadChanges() {
  isClusterInitialized || return 0
  if $IS_UPGRADING_FROM_V2; then return 0; fi
  local cmd; for cmd in $RELOAD_COMMANDS; do
    execute ${cmd//:/ }; if [[ "$cmd" =~ ^reloadKube(LogLevel|ApiserverArgs)$ ]]; then return 0; fi
  done
}

prepareKubeletEnv() {
  if isMaster && isClusterInitialized; then ensureCertsValid; fi
  hostname $(getMyNodeName)
  setUpResolvConf
  swapoff -a
}

initFirstNode() {
  if $IS_HA_CLUSTER; then
    log --debug "creating lb ..."
    startSvc kube-lb
  fi
  log --debug "botstraping first master ..."
  bootstrap
  log --debug "distributing join command to other nodes ..."
  distributeJoinCmd
  log --debug "distributing kube.config to worker and client nodes ..."
  distributeKubeConfig
  if $IS_HA_CLUSTER; then
    log --debug "waiting kube lb is created ..."
    waitKubeLbJobDone
    log --debug "applying lb ..."
    updateLbIp
    log --debug "waiting for LB becomes stable ..."
    waitLbIpAppliedToAllMasters
  fi
  log --debug "applying kube-proxy log level ..."
  applyKubeProxyLogLevel
  log --debug "setting up network ..."
  setUpNetwork
  if test -z "$STABLE_WORKER_NODES"; then
    log --debug "marking master-only cluster nodes ..."
    markAllInOne
  fi
  log --debug "setting up DNS ..."
  setUpDns
  log --debug "waiting for kube-dns resolving qingcloud api server ..."
  warmUpDns
  log --debug "waiting for all nodes to be ready ..."
  waitAllNodesReady
  if $NODELOCALDNS_ENABLED; then
    log --debug "setting up nodelocaldns ..."
    setUpNodeLocalDns
  fi
  log --debug "setting up cloud controller manager ..."
  setUpCloudControllerMgr
  log --debug "setting up storage ..."
  setUpStorage
  removeTokens
  if $KS_ENABLED; then
    log --debug "launch ks-installer ..."
    startSvc ks-installer
  fi
}

initOtherNode() {
  local -r joining="$JOINING_MASTER_NODES$JOINING_WORKER_NODES" firstMasterIp="$(getFirstMasterIp)"
  log --debug "preparing join command file ..."
  if [ -n "$joining" ]; then scp $firstMasterIp:$JOIN_CMD_FILE $JOIN_CMD_FILE; else retry 240 1 0 test -s $JOIN_CMD_FILE; fi
  if isMaster; then
    log --debug "joining cluster as master ..."
    retry 3 1 0 bash $JOIN_CMD_FILE
  fi
  if $IS_HA_CLUSTER; then
    log --debug "preparing apiserver lb file ..."
    if [ -n "$joining" ]; then scp $firstMasterIp:$APISERVER_LB_FILE $APISERVER_LB_FILE; else retry 600 1 0 test -s $APISERVER_LB_FILE; fi
    log --debug "updating lb ip ..."
    updateLbIp
    if [ -z "$joining" ]; then
      log --debug "waiting for LB becomes stable ..."
      waitLbIpAppliedToAllMasters
    fi
  fi
  if ! isMaster; then
    log --debug "joining cluster as worker ..."
    retry 60 1 0 bash $JOIN_CMD_FILE
  fi
  log --debug "preparing kubeconfig file ..."
  if [ -n "$joining" ]; then scp $firstMasterIp:$KUBE_CONFIG $KUBE_CONFIG; else retry 60 1 0 test -s $KUBE_CONFIG; fi
  log --debug "waiting joined cluster ..."
  retry 30 1 0 runKubectl get no $(getMyNodeName) --no-headers
  log --debug "labeling ..."
  if isMaster; then
    if test -z "$STABLE_WORKER_NODES"; then
      log --debug "marking master-only cluster nodes ..."
      markAllInOne
    fi
  else
    markWorker
    if isGpuNode; then markGpuNode; setUpGpuPlugin; fi
  fi
}

runKubeadm() {
  kubeadm --config $KUBEADM_CONFIG "$@"
}

runKubectlCreate() {
  runKubectl create $@ --dry-run -oyaml | runKubectl apply -f -
}

runKubectlDelete() {
  if runKubectl get $@ --no-headers -oname; then runKubectl delete $@; fi
}

runKubectlPatch() {
  if runKubectl get $1 $2 --no-headers -oname; then runKubectl patch $1 $2 $3 "$4"; fi
}

runKubectl() {
  kubectl --kubeconfig $KUBE_CONFIG "$@"
}

bootstrap() {
  local -r initLogFile=/data/appctl/logs/init.log
  rotate $initLogFile
  runKubeadm init --skip-phases preflight,certs/etcd-ca,certs/etcd-server,certs/etcd-peer,certs/etcd-healthcheck-client,certs/apiserver-etcd-client,etcd --upload-certs | tee $initLogFile

  # You can now join any number of the control-plane node running the following command on each as root:
  #
  #   kubeadm join loadbalancer:6443 --token pr...zb \
  #     --discovery-token-ca-cert-hash sha256:d6..b3 \
  #     --control-plane --certificate-key d7..cd
  grep -F 'join any number of the control-plane node running the following command' -A4 $initLogFile | sed '1,2d' > $JOIN_CMD_FILE
}

generateJoinCmd() {
  kubeadm token create --ttl 2h --print-join-command > $JOIN_CMD_FILE
}

waitLbIpAppliedToAllMasters() {
  local lbIp; lbIp="$(getLbIpFromFile)" || return $EC_IAAS_FAILED
  local master; for master in $(getColumns $INDEX_NODE_IP "$STABLE_MASTER_NODES"); do
    retry 30 1 0 checkLbIpAppliedToMaster $lbIp $master
  done
}

checkLbIpAppliedToMaster() {
  openssl s_client -connect $2:6443 </dev/null | openssl x509 -noout -ext subjectAltName | sed 's/, /\n/g' | grep -o "^IP Address:$1$"
}

waitAllNodesReady() {
  retry 300 1 0 checkNodeStats '$2=="Ready"'
}

waitPreviousMastersUpgraded() {
  local nodes="$(echo $STABLE_MASTER_NODES | awk -F"stable/master/$MY_SID/" '{print $1}')"
  test -z "$nodes" || retry 1800 2 0 checkNodeStats '$5=="v'$K8S_VERSION'"' $nodes
}

waitAllNodesUpgraded() {
  retry 3600 2 0 checkNodeStats '$5=="v'$K8S_VERSION'"'
}

waitAllMasterNodesUpgradedAndReady() {
  retry 3600 2 0 checkNodeStats '$2=="Ready"&&$3~/master/&&$5=="v'$K8S_VERSION'"' $STABLE_MASTER_NODES $JOINING_MASTER_NODES
}

waitAllNodesUpgradedAndReady() {
  retry 600 1 0 checkNodeStats '$2=="Ready"&&$5=="v'$K8S_VERSION'"'
}

checkNodeStats() {
  local nodes="${@:2}"
  local expected; expected="$(getNodeNames ${nodes:-$STABLE_MASTER_NODES $JOINING_MASTER_NODES $STABLE_WORKER_NODES $JOINING_WORKER_NODES} | sort)"
  local actual; actual="$(runKubectl get no --no-headers | awk $1' {print $1}' | sort | grep -o "$expected")"
  [ "$expected" = "$actual" ]
}

removeTokens() {
  local -r tokens="$(kubeadm token list | awk 'NR>1 {print $1}')"
  test -z "$tokens" || kubeadm token delete $tokens
}

getFirstMasterIp() {
  getColumns $INDEX_NODE_IP "${STABLE_MASTER_NODES%% *}"
}

isMaster() {
  [ "$MY_ROLE" = "master" ]
}

isFirstMaster() {
  isMaster && [ "$MY_SID" = "1" ]
}

isGpuNode() {
  [ "$MY_ROLE" = "node_gpu" ]
}

distributeJoinCmd() {
  distributeFile $JOIN_CMD_FILE $STABLE_MASTER_NODES
  sed -i '/--control-plane --cert.*$/d' $JOIN_CMD_FILE
  distributeFile $JOIN_CMD_FILE $STABLE_WORKER_NODES
}

distributeKubeConfig() {
  distributeFile $KUBE_CONFIG ${@:-$STABLE_WORKER_NODES $STABLE_CLIENT_NODES}
}

checkKubeLbHealthy() {
  [ "$(curl -sk -m3 https://loadbalancer:6443/healthz)" = "ok" ]
}

upgradeCniConf() {
  [ "$NET_PLUGIN" = "flannel" ] || return 0
  yq w -ijP /etc/cni/net.d/10-flannel.conflist cniVersion 0.2.0
}

setUpNetwork() {
  sed "s@192\.168\.0\.0/16@$POD_SUBNET@" /opt/app/current/conf/k8s/calico-stable.yml > /opt/app/current/conf/k8s/calico.yml
  sed "s@10\.244\.0\.0/16@$POD_SUBNET@" /opt/app/current/conf/k8s/flannel-stable.yml > /opt/app/current/conf/k8s/flannel.yml
  runKubectl apply -f /opt/app/current/conf/k8s/$NET_PLUGIN.yml
}

setUpDns() {
  local fwdRule="forward . /etc/resolv.conf"
  runKubectl -n kube-system get cm coredns -oyaml |
      yq d - metadata.resourceVersion |
      yq d - metadata.annotations[kubectl.kubernetes.io/last-applied-configuration] |
      sed -r "s|^(.*)($fwdRule)$|\1\2 {\n\1  policy sequential\n\1}|" |
      runKubectl -n kube-system apply -f -
  runKubectl -n kube-system rollout restart deploy coredns
}

warmUpDns() {
  local inClusterDns; inClusterDns="$(runKubectl -n kube-system get svc kube-dns --template '{{.spec.clusterIP}}')"
  retry 30 1 0 queryKubeDns $CLUSTER_API_SERVER $inClusterDns || log 'WARN: seems kube-dns is not ready.'
}

queryKubeDns() {
  dig +timeout=2 +short $1 @$2 | grep -o "^[0-9.]\+"
}

setUpNodeLocalDns() {
  # https://v1-16.docs.kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/#configuration
  local kubeDns; kubeDns="$(runKubectl -n kube-system get svc kube-dns -o jsonpath={.spec.clusterIP})"
  local -r localDns=169.254.25.10
  local -r replaceRules="s/__PILLAR__LOCAL__DNS__/$localDns/g; s/__PILLAR__DNS__DOMAIN__/$DNS_DOMAIN/g; s/__PILLAR__DNS__SERVER__/$kubeDns/g"
  sed "$replaceRules" /opt/app/current/conf/k8s/nodelocaldns-$K8S_VERSION.yml | runKubectl apply -f -
}

setUpStorage() {
  local csiNode; for csiNode in $(getColumns $INDEX_NODE_INSTANCE_ID $STABLE_MASTER_NODES $STABLE_WORKER_NODES); do
    runKubectlDelete -n kube-system csinode $csiNode
  done
  runKubectlDelete -n kube-system sts csi-qingcloud-controller
  runKubectlDelete -n kube-system csidriver csi-qingcloud
  runKubectlDelete -n kube-system ds csi-qingcloud-node
  local -r csiDefaultFile=/opt/app/current/conf/k8s/csi-qingcloud-$QINGCLOUD_CSI_VERSION.yml
  local -r qingcloudCfgDefaultFile=/opt/app/current/conf/qingcloud/config.default.yaml
  yq r -d18 $csiDefaultFile data[config.yaml] > $qingcloudCfgDefaultFile
  yq w -d18 $csiDefaultFile data[config.yaml] -- "$(yq m -a $QINGCLOUD_CONFIG $qingcloudCfgDefaultFile)" | runKubectl apply -f -
  runKubectl apply -f /opt/app/current/conf/k8s/csi-sc.yml
  if $UPGRADED_FROM_V1; then
    local patch="allowVolumeExpansion: true"
    runKubectlPatch sc csi-qingcloud -p "$patch"
    runKubectlPatch sc neonsan -p "$patch"
  fi
}

checkStorageReady() {
  runKubectl get sc csi-qingcloud -o jsonpath={.metadata.annotations.'storageclass\.kubernetes\.io/is-default-class'}
}

setUpCloudControllerMgr() {
  runKubectlCreate -n kube-system configmap lbconfig --from-file=/opt/app/current/conf/qingcloud/qingcloud.yaml
  runKubectlCreate -n kube-system secret generic qcsecret --from-file=$QINGCLOUD_CONFIG
  runKubectl -n kube-system apply -f /opt/app/current/conf/k8s/cloud-controller-manager-$QINGCLOUD_CCM_VERSION.yml
}

# called by systemd
setUpKs() {
  log --debug "launching kubesphere ..."
  launchKs
  log --debug "wating kubesphere to be ready ..."
  waitKsReady
}

launchKs() {
  ksPrepareCerts() {
    runKubectlCreate ns kubesphere-system
    runKubectlCreate -n kubesphere-system secret generic kubesphere-ca --from-file=ca.crt=/etc/kubernetes/pki/ca.crt --from-file=ca.key=/etc/kubernetes/pki/ca.key
    runKubectlCreate ns kubesphere-monitoring-system
    runKubectlCreate -n kubesphere-monitoring-system secret generic kube-etcd-client-certs
  }

  ksPrepareCerts
  applyKsConf
  reloadExternalElk
}

applyKsConf() {
  local -r ksInstallerDefaultFile=/opt/app/current/conf/k8s/ks-installer-stable.yml
  local -r ksCfgDefaultFile=/opt/app/current/conf/k8s/ks-config.default.yml
  local -r ksCfgDynamicFile=/opt/app/current/conf/k8s/ks-config.dynamic.yml

  yq r -d1 $ksInstallerDefaultFile data[ks-config.yaml] > $ksCfgDefaultFile
  yq w -d1 $ksInstallerDefaultFile data[ks-config.yaml] -- "$(yq m -a $ksCfgDynamicFile $ksCfgDefaultFile | sed '1i\---' | sed '$G; $a # END')" | runKubectl apply -f -
}

reloadExternalElk() {
  if $ELK_PROVIDED && isMaster; then runKubectl apply -f /opt/app/current/conf/k8s/external-elk-svc.yml; fi
}

waitKsReady() {
  retry 1800 2 $EC_KS_INSTALL_DONE_WITH_ERR keepKsInstallerRunningTillDone
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
  local output; output="$(runKubectl -n kubesphere-system logs --tail 22 $podName)" || return $EC_KS_INSTALL_LOGS_ERR
  if echo "$output" | grep "^PLAY RECAP **" -A1 | egrep -o "failed=[1-9]"; then return $EC_KS_INSTALL_FAILED; fi
  echo "$output" | grep -oF 'Welcome to KubeSphere!' || return $EC_KS_INSTALL_RUNNING
  echo "$output" | grep -oF "total: $KS_MODULES_COUNT     completed:$KS_MODULES_COUNT" || return $EC_KS_INSTALL_DONE_WITH_ERR
}

getKsInstallerPodName() {
  runKubectl -n kubesphere-system get pod -l app=ks-install --field-selector status.phase=Running -ojsonpath='{.items[0].metadata.name}' | grep ks-installer
}

setUpGpuPlugin() {
  runKubectl apply -f /opt/app/current/conf/k8s/nvidia-plugin-$NVIDIA_PLUGIN_VERSION.yml
}

getNodeNames() {
  if ! $UPGRADED_FROM_V1 && $NODE_NAME_HUMAN_READABLE; then
    getColumns $INDEX_NODE_NAME $@
  else
    getColumns $INDEX_NODE_INSTANCE_ID $@
  fi
}

readonly INDEX_NODE_ROLE=2
readonly INDEX_NODE_INSTANCE_ID=4
readonly INDEX_NODE_NAME=5
readonly INDEX_NODE_ID=6
readonly INDEX_NODE_IP=7

getColumns() {
  echo ${@:2} | xargs -n1 | awk -F/ '{print $'$1'}'
}

getMyNodeName() {
  if ! $UPGRADED_FROM_V1 && $NODE_NAME_HUMAN_READABLE; then
    echo $MY_NODE_NAME
  else
    echo $MY_INSTANCE_ID
  fi
}

. /opt/app/current/bin/node/iaas.sh

setUpKubeLb() {
  saveLbFile notready
  local sg; sg="$(iaasCreateSecurityGroup $CLUSTER_ID)"
  iaasTagResource $CLUSTER_TAG security_group $sg
  iaasAddSecurityRules $sg $CLUSTER_ZONE
  iaasApplySecurityGroup $sg
  local lbId; lbId="$(iaasCreateLb $CLUSTER_ID $CLUSTER_VXNET $sg)"
  iaasTagResource $CLUSTER_TAG loadbalancer $lbId
  sleep 30
  retry 300 2 0 checkLbActive $lbId
  local listener; listener="$(iaasCreateListener $lbId)"
  local -r instanceIds="$(getColumns $INDEX_NODE_INSTANCE_ID $STABLE_MASTER_NODES $JOINING_MASTER_NODES)"
  iaasAddLbBackends $listener $instanceIds
  iaasApplyLb $lbId
  retry 30 1 0 checkLbApplied $lbId
  local lbIp; lbIp="$(iaasDescribeLb $lbId vxnet.private_ip)"
  saveLbFile $lbId/$lbIp
}

fixLbListener() {
  local lbId; lbId="$(iaasRunCli describe-loadbalancers -W $CLUSTER_ID | jq -r '.loadbalancer_set[] | select(.vxnet.vxnet_id == "'$CLUSTER_VXNET'" and .vxnet.private_ip == "'$LB_IP_FROM_V1'") | .loadbalancer_id')"
  local lbListenerId; lbListenerId="$(iaasRunCli describe-loadbalancer-listeners -l $lbId | jq -r '.loadbalancer_listener_set[] | select(.listener_port == 6443) | .loadbalancer_listener_id')"
  log "fixing scene value of previously created LB listener [$lbId $lbListenerId] ..."
  iaasFixLbListener $lbListenerId $CLUSTER_ZONE || return $?
  iaasApplyLb $lbId || return $?
  echo -n $lbId
}

checkLbActive() {
  [ "$(iaasDescribeLb $1 status)" = "active" ]
  [ "$(iaasDescribeLb $1 transition_status)" = "" ]
}

checkLbApplied() {
  test $(iaasDescribeLb $1 is_applied) -eq 1
}

saveLbFile() {
  echo -n "$1" > $APISERVER_LB_FILE
}

getLbIpFromFile() {
  awk -F/ '{print $2}' $APISERVER_LB_FILE | grep ^[0-9.]\\+$
}

distributeKubeLbFile() {
  distributeFile $APISERVER_LB_FILE ${@:-$STABLE_MASTER_NODES $STABLE_WORKER_NODES $STABLE_CLIENT_NODES}
}

waitKubeLbJobDone() {
  retry 600 1 0 checkKubeLbJobDone
}

checkKubeLbJobDone() {
  ! systemctl is-active -q kube-lb
}

updateLbIp() {
  local lbIp; lbIp="$(getLbIpFromFile)" || return $EC_IAAS_FAILED
  sed -ri "s/^[0-9.]+(\s+loadbalancer)/$lbIp\1/" /etc/hosts
  if isMaster; then
    local -r objPath=apiServer.certSANs certSansFile=/opt/app/current/conf/k8s/cert-sans.yml marker='# Load Balancer IP'
    if yq r -d1 $KUBEADM_CONFIG $objPath | grep -vF "$lbIp $marker"; then
      rotate $KUBEADM_CONFIG
      yq r -d1 $KUBEADM_CONFIG $objPath | (sed "/$marker/d"; echo "- $lbIp $marker") | yq p - $objPath > $certSansFile
      yq m -x -i -d1 $KUBEADM_CONFIG $certSansFile
      updateApiserverCerts
      reloadMasterProcs
    fi
  fi
}

distributeFile() {
  local node ip role; for node in ${@:2}; do
    ip="$(getColumns $INDEX_NODE_IP $node)"
    role="$(getColumns $INDEX_NODE_ROLE $node)"
    if [ "$ip" != "$MY_IP" ]; then
      scp -r $1 $ip:$1 || [ "$role" = "client" ] || return $?
    fi
  done
}

reloadKsEip() {
  if $KS_ENABLED && isMaster; then runKubectl -n kubesphere-system patch svc ks-console -p "$(cat /opt/app/current/conf/k8s/ks-console-svc.yml)"; fi
}

reloadKsConf() {
  if $KS_ENABLED && isMaster; then applyKsConf; fi
}

reloadKubeApiserverCerts() {
  if isMaster; then updateApiserverCerts; fi
}

reloadKubeApiserverArgs() {
  isMaster || return 0
  rotate /etc/kubernetes/manifests/kube-apiserver.yaml
  initControlPlane apiserver
  if isFirstMaster; then runKubeadm init phase upload-config kubeadm; fi
}

reloadMasterProcs() {
  isMaster || return 0
  local allProcs="kube-apiserver kube-controller-manager kube-scheduler"
  local proc; for proc in ${@:-$allProcs}; do
    kill -s SIGHUP $(pidof $proc) && retry 5 1 0 pidof $proc || log "WARN: failed to SIGHUP to '$proc'."
  done
}

reloadKubeLogLevel() {
  isMaster || return 0
  runKubeadm init phase upload-config kubeadm
  retry 60 1 0 applyKubeProxyLogLevel
  sleep $(( $RANDOM % 5 + 1 ))
  rotate $(find /etc/kubernetes/manifests -mindepth 1 -maxdepth 1 -name '*.yaml')
  initControlPlane
}

applyKubeProxyLogLevel() {
  local -r type=daemonsets.app name=kube-proxy
  runKubectl -n kube-system patch $type $name -p "$(runKubectl -n kube-system get $type $name -oyaml | updateLogLevel $name)"
}

updateLogLevel() {
  local -r field=spec.template.spec.containers[0]
  yq r - $field.command | sed '/^- --v=/d' | yq w - [+] -- "--v=$K8S_LOG_LEVEL"  | yq p - $field.command | yq w - $field.name $1
}

updateApiserverCerts() {
  rotate -m $(ls /etc/kubernetes/pki/apiserver.{crt,key})
  runKubeadm init phase certs apiserver
}

annotateInstanceId() {
  runKubectl annotate no $(getMyNodeName) node.beta.kubernetes.io/instance-id="$MY_INSTANCE_ID"
}

markAllInOne() {
  local hostName; hostName=${1:-$(getMyNodeName)}
  runKubectl taint node $hostName node-role.kubernetes.io/master:NoSchedule-
}

markWorker() {
  local -r role=${1:-$MY_ROLE}
  local hostName; hostName=${2:-$(getMyNodeName)}
  local label="$role=" && $UPGRADED_FROM_V1 || label="worker=$role"
  runKubectl label node $hostName node-role.kubernetes.io/$label
}

markGpuNode() {
  local -r role=${1:-$MY_ROLE}
  local hostName; hostName=${2:-$(getMyNodeName)}
  local model; model="$(nvidia-smi --query-gpu=name --format=csv,noheader)"
  runKubectl label node $hostName hardware-type=NVIDIAGPU \
                                  nvidia.com/brand=$(echo ${model,,} | sed 's/ /-/g') \
                                  accelerator=$(echo ${model,,} | sed 's/-.*//g; s/ /-/g; s/^/nvidia-/')
}

runDockerPrune() {
  local days="$DOCKER_PRUNE_DAYS" && test -z "$1" || days="$(echo $1 | jq -r '.max_days')"
  docker system prune -f --filter "until=$(( $days * 24 ))h"
}

ensureCertsValid() {
  checkCertDaysBeyond 30 || renewCerts
}

checkCertDaysBeyond() {
  test $(getCertValidDays) -gt $1
}

getCertValidDays() {
  local earliestExpireDate; earliestExpireDate="$(runKubeadm alpha certs check-expiration | awk '$1!~/^$|^CERTIFICATE/ {print "date -d\"",$2,$3,$4,$5,"\" +%s" | "/bin/bash"}' | sort -n | head -1)"
  local today; today="$(date +%s)"
  echo -n $(( ($earliestExpireDate - $today) / (24 * 60 * 60) ))
}

renewCerts() {
  local crt; for crt in ${@:-admin.conf apiserver apiserver-kubelet-client controller-manager.conf front-proxy-client scheduler.conf}; do kubeadm alpha certs renew $crt; done
  reloadMasterProcs
  if isFirstMaster; then distributeKubeConfig; fi
}

fixOverlays() {
  local transientRoot persistentRoot; persistentRoot=/data/var/lib/docker/overlay2 
  if $IS_UPGRADING_FROM_V1; then
    transientRoot=/opt/overlay2
  elif $IS_UPGRADING_FROM_V2; then
    transientRoot=/var/lib/docker/overlay2
  fi
  local layer; for layer in $(find $persistentRoot -mindepth 1 -maxdepth 1 -type l -exec basename {} \;); do
    local transientLayer="$transientRoot/$layer/"
    if [[ -d "$transientLayer" ]]; then 
      rsync -aAX $transientLayer $persistentRoot/$layer.tmp/ || {
        log "ERROR: failed to copy '$layer' from '$transientRoot' to '$persistentRoot'. Reverting ..."
        rm -rf $persistentRoot/$layer.tmp
        return $EC_OVERLAY_ERR
      }
      rm -f $persistentRoot/$layer
      mv $persistentRoot/$layer.tmp $persistentRoot/$layer
    fi
  done
}

setUpResolvConf() {
  isClusterInitialized || return 0
  local flagFile=/var/lib/kubelet/kubeadm-flags.env flagKey="--resolv-conf"
  if grep -vq -- "$flagKey=" $flagFile && checkActive systemd-resolved; then
    log "Setting up resolv-conf ..."
    rotate $flagFile
    sed -i "s#--#$flagKey=/run/systemd/resolve/resolv.conf --#" $flagFile
  fi
}

getKubeConfig() {
  local urlAuthority
  if [ -n "$K8S_API_HOST" ]; then
    urlAuthority=$K8S_API_HOST:$K8S_API_PORT
  else
    urlAuthority="$($IS_HA_CLUSTER && isClusterInitialized && getLbIpFromFile || getFirstMasterIp):6443"
  fi
  sed "s/loadbalancer:6443/$urlAuthority/g" $KUBE_CONFIG | jq -Rsc '{labels: ["Kubeconfig"], data: [[.]]}'
}

getKsUrl() {
  renderJson() {
    echo -n "$1|$2" | jq -Rsc 'split("|") | {labels: ["kubesphere_console", "ks_console_notes"], data: [.]}'
  }

  local ksConsoleSvc; ksConsoleSvc="$(runKubectl get svc -n kubesphere-system ks-console -oyaml)" || {
    if $KS_ENABLED; then
      log "ERROR: failed to retrieve ks-console.kubesphere-system.svc ($?)."
      renderJson "Failed to retrieve ks-console info. Please try again later."
    else
      renderJson "KS is not installed."
    fi
    return 0
  }

  local -r firstMasterIp="$(getFirstMasterIp)"
  local -r svcType="$(echo "$ksConsoleSvc" | yq r - spec.type)"
  local -r nodePort="$(echo "$ksConsoleSvc" | yq r - spec.ports[0].nodePort)"
  local -r msgLbNotReady="Using master node IP. Please try again later when external IP is ready."
  if [ "$svcType" = "NodePort" ]; then
    renderJson "http://$firstMasterIp:$nodePort" "$(test -z "$KS_EIP_ID" || echo -n $msgLbNotReady)"
  elif [ "$svcType" = "LoadBalancer" ]; then
    local -r lbIp="$(echo "$ksConsoleSvc" | yq r - status.loadBalancer.ingress[0].ip)" lbPort="$(echo "$ksConsoleSvc" | yq r - spec.ports[0].port)"
    if test -n "$lbIp"; then
      renderJson "http://$lbIp:$lbPort"
    else
      renderJson "http://$firstMasterIp:$nodePort" "$msgLbNotReady"
    fi
  else
    renderJson "Something went wrong, but you should ensure ks-console service in kubesphere-system is of type 'LoadBalancer' or 'NodePort'."
  fi
}

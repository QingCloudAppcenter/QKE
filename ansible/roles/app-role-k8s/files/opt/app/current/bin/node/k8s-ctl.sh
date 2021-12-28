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
EC_HOSTNIC_VXNETS_INVALID
EC_HOSTNIC_VXNETS_LACKING
EC_HOSTNIC_VXNETS_UNKNOWN
EC_HOSTNIC_VPCS_MISMATCHED
EC_DNS_ERR
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
  mkdir -p /data/{backup/csi,kubernetes/{audit/{logs,policies,webhooks},manifests,backup/manifests}} /data/var/lib/etcd
  ln -snf /data/kubernetes /etc/kubernetes
  local migratingPath; for migratingPath in root/{.docker,.kube,.config,.cache,.local,.helm} var/lib/{hostnic,kubelet}; do
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
  syncKubeAuditFiles --init
  ln -snf $KUBE_CONFIG /root/.kube/config
  chown -R etcd /data/var/lib/etcd
}

start() {
  log "starting node ..."
  isNodeInitialized || initNode
  prepareKubeletEnv
  _start
  log "started node."
}

startSvc() {
  local svcName=${1%%/*}
  if [ "$svcName" = "kubelet" ]; then
    setUpHostnicRules
  fi
  _startSvc $@
}

initCluster() {
  log "initializing cluster ..."
  _initCluster
  log "warm up DNS ..."
  warmUpLocalDns
  if isFirstMaster; then initFirstNode; else initOtherNode; fi
  annotateInstanceId
  labelTopology
  rm -rf $JOIN_CMD_FILE
  log "done initializing cluster!"
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
  local result; result="$( (runKubectl drain $nodes --ignore-daemonsets --delete-emptydir-data --timeout=6m --force && runKubectl delete no --timeout=3m $nodes) 2>&1)" || {
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
  local -r baseDir=/etc/kubernetes/manifests
  local -r backupDir=/data/kubernetes/backup/manifests
  local component; for component in ${@:-apiserver controller-manager scheduler}; do
    cp $baseDir/kube-$component.yaml $backupDir/
    rotate -m $backupDir/kube-$component.yaml
  done
  runKubeadm init phase control-plane ${@:-all}
}

upgrade() {
  log "upgrading node ..."
  $IS_UPGRADING || return $UPGRADE_VERSION_DETECTED_ERR
  upgradeCniConf

  if $IS_UPGRADING_FROM_V2; then
    docker load -qi $UPGRADE_DIR/docker-images/k8s-v2.tgz
    if $KS_ENABLED; then docker load -qi $UPGRADE_DIR/docker-images/ks-v2.tgz; fi
  fi
  docker load -qi $UPGRADE_DIR/docker-images/k8s.tgz
  if $KS_ENABLED; then docker load -qi $UPGRADE_DIR/docker-images/ks.tgz; fi
  fixOverlays

  initNode
  start
  if isMaster; then
    log "upgrading master node..."
    waitPreviousMastersUpgraded
    updateApiserverCerts
    log "$KUBEADM_CONFIG contents: $(cat $KUBEADM_CONFIG)"
    initControlPlane
    if isFirstMaster && $IS_UPGRADING; then
      log --debug "fix kubelet.conf issue: https://github.com/QingCloudAppcenter/QKE/issues/294"
      runKubeadm init phase kubelet-finalize experimental-cert-rotation
    fi
    log "init phase kubelet-start"
    runKubeadm init phase kubelet-start
    restartSvc kubelet

    if isFirstMaster; then
      log "distributeFile from first master"
      local path; for path in $(ls /var/lib/kubelet/{config.yaml,kubeadm-flags.env}); do
        log "$path:$(cat $path)"
        distributeFile $path $STABLE_WORKER_NODES
      done
      distributeKubeConfig

      waitAllNodesUpgradedAndReady
      runKubeadm init phase upload-config all
      # runKubectl annotate node $(getMyNodeName) kubeadm.alpha.kubernetes.io/cri-socket=/var/run/dockershim.sock
      # kubeadm upgrade node: unable to fetch the kubeadm-config ConfigMap: failed to getAPIEndpoint
      # runKubectlPatch cm kubeadm-config -p "$(yq n data.ClusterStatus -- "$(yq w /tmp/cm.yml data.ClusterStatus -- "$(for m in $STABLE_MASTER_NODES; do printf "%s:\n  advertiseAddress: %s\n  bindPort: 6443\n" $(echo $m | awk -F/ '{print $4, $7}'); done | yq p - apiEndpoints)")")"
      local ignoredErrors=CoreDNSUnsupportedPlugins
      if $IS_UPGRADING_FROM_V3; then
        ignoredErrors="$ignoredErrors,CoreDNSMigration"
      fi
      kubeadm upgrade apply v$K8S_VERSION --ignore-preflight-errors=$ignoredErrors -f
      if $IS_UPGRADING_FROM_V3; then
        # TODO: remove this after K8s 1.19.0: https://github.com/kubernetes/kubernetes/issues/88725
        retry 10 1 0 fixDns
      fi
      applyKubeProxyLogLevel
      # restart metrics-server to avoid https://github.com/kubernetes/kubernetes/pull/96371
      setUpNetwork
      setUpCloudControllerMgr
      execute setUpStorage
    fi
    log "upgraded master node."
  else
    log "upgrading worker node..."
    waitAllMasterNodesUpgradedAndReady
    restartSvc kubelet
    log "upgraded worker node."
  fi
  if isFirstMaster && $KS_ENABLED; then
    if $IS_UPGRADING_FROM_V3; then
      resetAuditingModule
    fi
    runKubectl -n kube-system rollout restart deploy metrics-server
    launchKs
  fi
  _initCluster
  log "upgraded node."
}

check() {
  _check
  checkNodeStats '$2~/^Ready/' $(getMyNodeName)
}

checkSvc() {
  _checkSvc $@ || return $?
  local svcName=${1%%/*}
  if [ "$svcName" = "kubelet" ]; then [ "$(curl -s -m 5 localhost:10248/healthz)" = "ok" ]; fi
  if [ "$svcName" = "hostnic-status" ]; then checkHostnicHealthy; fi
  if [ "$svcName" = "kube-certs.timer" ]; then checkCertDaysBeyond 25; fi
}

revive() {
  prepareKubeletEnv
  _revive
}

# in v1.19.8 metrics are changed from:
#   kubelet_running_container_count => kubelet_running_containers
#   kubelet_running_pod_count => kubelet_running_pods
measure() {
  isClusterInitialized && isNodeInitialized || return 0
  local -r regex="$(sed 's/^\s*//g' <<< '
    kubelet_running_containers{container_state="running"}
    kubelet_running_pods
  ' | paste -sd'|' | sed 's/^|/^(/; s/|$/)/')"
  runKubectl get -s https://localhost:10250 --raw /metrics --insecure-skip-tls-verify | egrep "$regex" | sed -r 's/\{[^}]+\}//g; s/ /: /g' | yq -j r -
}

reloadChanges() {
  isClusterInitialized || return 0
  if $IS_UPGRADING; then return 0; fi
  local cmd; for cmd in $RELOAD_COMMANDS; do
    execute ${cmd//:/ }; if [[ "$cmd" =~ ^reloadKube(LogLevel|MasterArgs:apiserver)$ ]]; then return 0; fi
  done
}

prepareKubeletEnv() {
  if isMaster && isClusterInitialized; then ensureCertsValid; fi
  hostname $(getMyNodeName)
  setUpResolvConf
  swapoff -a
}

initFirstNode() {
  if hasKubeLb; then
    log "creating lb ..."
    startSvc kube-lb
  fi
  log "botstraping first master ..."
  bootstrap
  log "distributing join command to other nodes ..."
  distributeJoinCmd
  log "distributing kube.config to worker and client nodes ..."
  distributeKubeConfig
  if hasKubeLb; then
    log "wait all master node joined"
    waitAllMasterNodesJoined
    log "waiting kube lb is created ..."
    waitKubeLbJobDone
    log "applying lb ..."
    updateLbIp
    log "waiting for LB becomes stable ..."
    waitLbIpAppliedToAllMasters
  fi
  log "applying kube-proxy log level ..."
  applyKubeProxyLogLevel
  log "setting up cloud secret ..."
  setUpCloudSecret
  log "setting up network ..."
  setUpNetwork
  if test -z "$STABLE_WORKER_NODES"; then
    log "marking master-only cluster nodes ..."
    markAllInOne
  fi
  log "setting up DNS ..."
  setUpDns
  log "checking if hostnic vxnets healthy ..."
  local hostnicStatus=0
  checkHostnicHealthy || hostnicStatus=$?
  if [ "$hostnicStatus" -eq 0 ]; then
    log "waiting for kube-dns resolving qingcloud api server ..."
    warmUpDns
  fi

  log "waiting for all nodes to be ready ..."
  waitAllNodesReady

  if $NODELOCALDNS_ENABLED; then
    log "setting up nodelocaldns ..."
    setUpNodeLocalDns
  fi
  log "setting up cloud controller manager ..."
  setUpCloudControllerMgr

  log "setting up storage ..."
  execute setUpStorage
  removeTokens
  if $KS_ENABLED; then
    log "launch ks-installer ..."
    startSvc ks-installer
  fi
  return $hostnicStatus
}

initOtherNode() {
  local -r joining="$JOINING_MASTER_NODES$JOINING_WORKER_NODES" firstMasterIp="$(getFirstMasterIp)"
  log "preparing join command file ..."
  # wait kubeAdmin: 3 minutes
  if [ -n "$joining" ]; then scp $firstMasterIp:$JOIN_CMD_FILE $JOIN_CMD_FILE; else retry 18 10 0 test -s $JOIN_CMD_FILE; fi
  if isMaster; then
    log "joining cluster as master ..."
    retry 3 2 0 bash $JOIN_CMD_FILE
  fi
  if hasKubeLb; then
    if [ -z "$joining" ]; then
      log "wait all master node joined"
      waitAllMasterNodesJoined
    fi
    log "preparing apiserver lb file ..."
    # wait setUpKubeLb: 8 minutes
    if [ -n "$joining" ]; then scp $firstMasterIp:$APISERVER_LB_FILE $APISERVER_LB_FILE; else retry 48 10 0 test -s $APISERVER_LB_FILE; fi
    log "updating lb ip ..."
    updateLbIp
    if [ -z "$joining" ]; then
      log "waiting for LB becomes stable ..."
      waitLbIpAppliedToAllMasters
    fi
  fi
  if ! isMaster; then
    log "joining cluster as worker ..."
    retry 3 2 0 bash $JOIN_CMD_FILE
  fi
  log "preparing kubeconfig file ..."
  if [ -n "$joining" ]; then scp $firstMasterIp:$KUBE_CONFIG $KUBE_CONFIG; else retry 6 10 0 test -s $KUBE_CONFIG; fi
  log "waiting joined cluster ..."
  retry 15 2 0 runKubectl get no $(getMyNodeName) --no-headers
  log "labeling ..."
  if isMaster; then
    if test -z "$STABLE_WORKER_NODES"; then
      log "marking master-only cluster nodes ..."
      markAllInOne
    fi
  else
    markWorker
    if isGpuNode; then
      markGpuNode
      execute setUpGpuPlugins
    fi
  fi
}

runKubeadm() {
  kubeadm --config $KUBEADM_CONFIG "$@"
}

runKubectlCreate() {
  runKubectl create $@ --dry-run=client -oyaml | runKubectl apply -f -
}

runKubectlDelete() {
  if runKubectl get $@ --no-headers -oname; then runKubectl delete $@; fi
}

runKubectlPatch() {
  if [ "$1" == "-n" ]; then
    local -r patchNs="$1 $2"
    shift 2
  fi
  if [ "$1" == "--type" ]; then
    local -r patchType="$1 $2"
    shift 2
  fi
  if runKubectl $patchNs get $1 $2 --no-headers -oname; then runKubectl $patchNs patch $patchType $1 $2 $3 "$4"; fi
}

runKubectl() {
  kubectl --kubeconfig $KUBE_CONFIG "$@"
}

runHelm() {
  /usr/local/bin/helm --kubeconfig $KUBE_CONFIG "$@"
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
    retry 15 2 0 checkLbIpAppliedToMaster $lbIp $master
  done
}

checkLbIpAppliedToMaster() {
  openssl s_client -connect $2:6443 </dev/null | openssl x509 -noout -ext subjectAltName | sed 's/, /\n/g' | grep -o "^IP Address:$1$"
}

waitAllNodesReady() {
  retry 60 10 0 checkNodeStats '$2=="Ready"'
}

waitPreviousMastersUpgraded() {
  local nodes="$(echo $STABLE_MASTER_NODES | awk -F"stable/master/$MY_SID/" '{print $1}')"
  test -z "$nodes" || retry 20 30 0 checkNodeStats '$5=="v'$K8S_VERSION'"' $nodes
}

waitAllMasterNodesUpgradedAndReady() {
  retry 60 10 0 checkNodeStats '$2~/^Ready/&&$3~/master/&&$5=="v'$K8S_VERSION'"' $STABLE_MASTER_NODES $JOINING_MASTER_NODES
}

waitAllNodesUpgradedAndReady() {
  retry 60 20 0 checkNodeStats '$2~/^Ready/&&$5=="v'$K8S_VERSION'"'
}

waitAllMasterNodesJoined(){
  retry 30 10 0 checkNodeStats '$3~/master/' $STABLE_MASTER_NODES $JOINING_MASTER_NODES
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

isUsingHostnic() {
  [ "$NET_PLUGIN" = "hostnic" ]
}

setUpNetwork() {
  local readonly baseDir=/opt/app/current/conf/k8s
  sed -r "s@192\.168\.0\.0/16@$POD_SUBNET@; s@# (- name: CALICO_IPV4POOL_CIDR)@\1@; s@# (  value: \"$POD_SUBNET\")@\1@" \
      $baseDir/calico-$CALICO_VERSION.yml > $baseDir/calico.yml
  sed "s@10\.244\.0\.0/16@$POD_SUBNET@" $baseDir/flannel-$FLANNEL_VERSION.yml > $baseDir/flannel.yml
  yq m -x -d3 $baseDir/hostnic-$HOSTNIC_VERSION.yml $baseDir/hostnic-cm.yml > $baseDir/hostnic.yml
  runKubectl apply -f $baseDir/$NET_PLUGIN.yml
  if isUsingHostnic; then
    runKubectl apply -f $baseDir/hostnic-policy-$HOSTNIC_VERSION.yml
  fi
}

warmUpLocalDns() {
  retry 5 2 0 restartLocalDnsIfNotReady || return $EC_DNS_ERR
}

setUpHostnicRules() {
  if isUsingHostnic; then
    iptables -t filter -P FORWARD ACCEPT
  fi
}

checkHostnicVxnets() {
  isUsingHostnic || return 0

  local readonly hostnicVxnetsCount=$(echo -n $HOSTNIC_VXNETS | wc -w)
  local hostnicResult; hostnicResult=$(iaasRunCli describe-vxnets -v ${HOSTNIC_VXNETS// /,} | jq -ec '.vxnet_set | length == '$hostnicVxnetsCount) || return $EC_HOSTNIC_VXNETS_INVALID

  local readonly k8sNodesCount=$(echo -n $STABLE_MASTER_NODES $STABLE_WORKER_NODES | wc -w)
  test $(( $hostnicVxnetsCount * 252 )) -ge $(( $k8sNodesCount * $HOSTNIC_MAX_NICS )) || return $EC_HOSTNIC_VXNETS_LACKING

  local readonly vxnetIds="$CLUSTER_VXNET $HOSTNIC_VXNETS"
  local readonly vxnetsCount=$(echo $vxnetIds | wc -w)
  local routers; routers=$(iaasRunCli describe-vxnets -v ${vxnetIds// /,} | jq -ec '[.vxnet_set[] | .vpc_router_id]') || return $EC_HOSTNIC_VXNETS_UNKNOWN

  local result; result=$(echo "$routers" | jq -e 'unique | length == 1') || return $EC_HOSTNIC_VPCS_MISMATCHED
}

fixDns() {
  local readonly jsonPath="spec.template.spec.volumes[0]"
  runKubectlPatch -n kube-system deploy coredns -p "$(runKubectl -n kube-system get deploy coredns -oyaml | yq r - $jsonPath | sed 's/Corefile-backup/Corefile/g' | yq p - $jsonPath)"
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
  retry 30 1 0 queryDns $CLUSTER_API_SERVER $inClusterDns || log 'WARN: seems kube-dns is not ready.'
}

restartLocalDnsIfNotReady() {
  queryDns $CLUSTER_API_SERVER || restartSvc systemd-networkd
}

queryDns() {
  local dns
  if [ -n "$2" ]; then dns=@$2; fi
  dig +timeout=2 +short $1 $dns | grep -o "^[0-9.]\+"
}

setUpNodeLocalDns() {
  # https://v1-16.docs.kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/#configuration
  local kubeDns; kubeDns="$(runKubectl -n kube-system get svc kube-dns -o jsonpath={.spec.clusterIP})"
  local -r localDns=169.254.25.10
  local -r replaceRules="s/__PILLAR__LOCAL__DNS__/$localDns/g; s/__PILLAR__DNS__DOMAIN__/$DNS_DOMAIN/g; s/__PILLAR__DNS__SERVER__/$kubeDns/g"
  sed "$replaceRules" /opt/app/current/conf/k8s/nodelocaldns-$K8S_VERSION.yml | runKubectl apply -f -
}

countUnBoundPVCs() {
  count=$(runKubectl get pvc -A --no-headers | grep -v Bound | wc -l)
  return ${count}
}

_setUpStorage() {
  # remove previous version
  if $IS_UPGRADING_FROM_V2; then
    runKubectl delete -f /opt/app/2.0.0/conf/k8s/csi-qingcloud-1.1.1.yml
  fi

  # CSI plugin
  local -r csiChartFile=/opt/app/current/conf/k8s/csi-qingcloud-$QINGCLOUD_CSI_VERSION.tgz
  local -r csiValuesFile=/opt/app/current/conf/k8s/csi-qingcloud-values.yml

  # Need to uninstall and reinstall if upgrading, because helm upgrade will fail due to
  #    immutable fields change during upgrade.
  if $IS_UPGRADING; then
    # make sure there no pending pvs, if not skip upgrading csi-qingcloud
    retry 60 10 0 countUnBoundPVCs || return 0
    runHelm -n kube-system uninstall csi-qingcloud
    runKubectl delete -f /opt/app/current/conf/k8s/csi-sc.yml || return 0
  fi

  yq p $QINGCLOUD_CONFIG config | cat - $csiValuesFile | \
      runHelm -n kube-system upgrade --install csi-qingcloud $csiChartFile -f -

  # Storage class
  runKubectl apply -f /opt/app/current/conf/k8s/csi-sc.yml
  if $UPGRADED_FROM_V1; then
    local scName; for scName in csi-qingcloud neonsan; do
      if runKubectl get sc $scName -oname; then
        upgradeStorageClass $scName
      fi
    done
  fi
}

upgradeStorageClass() {
  local readonly scFile=/data/backup/csi/$1.yml
  runKubectl get sc $1 -oyaml | yq w - allowVolumeExpansion true | yq w - parameters.tags $CLUSTER_TAG > $scFile
  runKubectlDelete sc $1
  runKubectl apply -f $scFile
}

checkStorageReady() {
  runKubectl get sc csi-qingcloud -o jsonpath={.metadata.annotations.'storageclass\.kubernetes\.io/is-default-class'}
}

setUpCloudSecret() {
  runKubectlCreate -n kube-system secret generic qcsecret --from-file=$QINGCLOUD_CONFIG
}

setUpCloudControllerMgr() {
  runKubectlCreate -n kube-system configmap lbconfig --from-file=/opt/app/current/conf/qingcloud/qingcloud.yaml
  runKubectl -n kube-system apply -f /opt/app/current/conf/k8s/cloud-controller-manager-$QINGCLOUD_CCM_VERSION.yml
}

# called by systemd
setUpKs() {
  log "launching kubesphere ..."
  launchKs
  log "wating kubesphere to be ready ..."
  waitKsReady
}

launchKs() {
  ksPrepareCerts() {
    runKubectlCreate ns kubesphere-system
    runKubectlCreate -n kubesphere-system secret generic kubesphere-ca --from-file=ca.crt=/etc/kubernetes/pki/ca.crt --from-file=ca.key=/etc/kubernetes/pki/ca.key
    runKubectlCreate ns kubesphere-monitoring-system
    runKubectlCreate -n kubesphere-monitoring-system secret generic kube-etcd-client-certs
  }

  ksRunInstaller() {
    if $IS_UPGRADING; then runKubectlDelete -n kubesphere-system deploy ks-installer; fi
    local readonly ksInstallerFile=/opt/app/current/conf/k8s/ks-installer-$KS_VERSION.yml
    sed "s#image: #image: $CUSTOM_REGISTRY#" $ksInstallerFile | runKubectl apply -f -
    buildKsConf | runKubectl apply -f -
  }

  ksPrepareCerts
  ksRunInstaller
  reloadExternalElk
}

buildKsDynamicConf() {
  local -r ksCfgDynamicFile=/opt/app/current/conf/k8s/ks-config.dynamic.yml
  if $IS_UPGRADING; then
    # components could be manually enabled
    runKubectl -n kubesphere-system get cc ks-installer -o yaml | yq r - 'spec' | yq p - spec
  else
    yq p $ksCfgDynamicFile spec
  fi
}

buildKsConf() {
  local -r ksCfgDefaultFile=/opt/app/current/conf/k8s/ks-config-$KS_VERSION.yml
  buildKsDynamicConf | yq m - $ksCfgDefaultFile
}

reloadExternalElk() {
  if $ELK_PROVIDED && isMaster; then runKubectl apply -f /opt/app/current/conf/k8s/external-elk-svc.yml; fi
}

waitKsReady() {
  # 20 minute
  retry 60 20 $EC_KS_INSTALL_DONE_WITH_ERR keepKsInstallerRunningTillDone
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
  local output; output="$(runKubectl -n kubesphere-system logs --tail 50 $podName)" || return $EC_KS_INSTALL_LOGS_ERR
  if echo "$output" | grep "^PLAY RECAP **" -A1 | egrep -o "failed=[1-9]"; then return $EC_KS_INSTALL_FAILED; fi
  echo "$output" | grep -oF 'Welcome to KubeSphere!' || return $EC_KS_INSTALL_RUNNING
  #local endStrings="is successful  ($KS_MODULES_COUNT/$KS_MODULES_COUNT)"
  if $IS_UPGRADING_FROM_V2; then endStrings=" failed=0 "; fi
  # if tail of installer log has line like "task openpitrix status is failed", means one or more components are failed
  # to install.
  !(echo "$output" | grep "Welcome to KubeSphere!" -B30 | grep -q "^task.*failed") || return $EC_KS_INSTALL_DONE_WITH_ERR
}

getKsInstallerPodName() {
  runKubectl -n kubesphere-system get pod -l app=ks-install --field-selector status.phase=Running -ojsonpath='{.items[0].metadata.name}' | grep ks-installer
}

_setUpGpuPlugins() {
  runKubectl apply -f /opt/app/current/conf/k8s/nvidia-plugin-$NVIDIA_PLUGIN_VERSION.yml
}

addGpuTolerations() {
  yq m -a $@ /opt/app/current/conf/k8s/gpu-tolerations.yml
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
  echo ${@:2} | xargs -n1 | cut -d/ -f$1
}

getMyNodeName() {
  if ! $UPGRADED_FROM_V1 && $NODE_NAME_HUMAN_READABLE; then
    echo $MY_NODE_NAME
  else
    echo $MY_INSTANCE_ID
  fi
}

hasKubeLb() {
  if [ -z "$KUBE_EIP_ID" ] && ! $IS_HA_CLUSTER; then
    return 1
  fi
}

setUpKubeLb() {
  saveLbFile notready
  local sg; sg="$(iaasCreateSecurityGroup $CLUSTER_ID)"
  iaasTagResource $CLUSTER_TAG security_group $sg
  iaasAddSecurityRules $sg $CLUSTER_ZONE
  iaasApplySecurityGroup $sg
  local lbId; lbId="$(iaasCreateLb $CLUSTER_ID $(execute getKubeLbVxnet) $sg)"
  iaasTagResource $CLUSTER_TAG loadbalancer $lbId
  sleep 30
  # 5 minutes is enough?
  retry 30 10 0 checkLbActive $lbId
  local listener; listener="$(iaasCreateListener $lbId)"
  local -r instanceIds="$(getColumns $INDEX_NODE_INSTANCE_ID $STABLE_MASTER_NODES $JOINING_MASTER_NODES)"
  iaasAddLbBackends $listener $instanceIds
  iaasApplyLb $lbId
  retry 12 10 0 checkLbApplied $lbId
  local lbIp; lbIp="$(iaasDescribeLb $lbId vxnet.private_ip)"
  if [ -n "$KUBE_EIP_ID" ]; then
    local lbEip; lbEip="$(iaasRunCli describe-eips -e $KUBE_EIP_ID | jq -er '.eip_set[0].eip_addr')"
    iaasRunCli associate-eips-to-loadbalancer -l $lbId -e $KUBE_EIP_ID
  fi
  saveLbFile $lbId/$lbIp/$lbEip
}

_getKubeLbVxnet() {
  echo -n $CLUSTER_VXNET
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

getLbEipFromFile() {
  awk -F/ '{print $3}' $APISERVER_LB_FILE | grep ^[0-9.]\\+$
}

distributeKubeLbFile() {
  distributeFile $APISERVER_LB_FILE ${@:-$STABLE_MASTER_NODES $STABLE_WORKER_NODES $STABLE_CLIENT_NODES}
}

waitKubeLbJobDone() {
  # wait setUpKubeLb: 8 minutes
  retry 48 10 0 checkKubeLbJobDone
}

checkKubeLbJobDone() {
  ! systemctl is-active -q kube-lb
}

updateLbIp() {
  local lbIp; lbIp="$(getLbIpFromFile)" || return $EC_IAAS_FAILED
  if [ -n "$KUBE_EIP_ID" ]; then
    local lbEip; lbEip="$(getLbEipFromFile)" || return $EC_IAAS_FAILED
  fi
  sed -ri "s/^[0-9.]+(\s+loadbalancer)/$lbIp\1/" /etc/hosts
  if isMaster; then
    local -r objPath=apiServer.certSANs certSansFile=/opt/app/current/conf/k8s/cert-sans.yml marker='# Load Balancer IP'
    if yq r -d1 $KUBEADM_CONFIG $objPath | grep -vF "$lbIp $marker"; then
      rotate $KUBEADM_CONFIG
      if [ -n "$KUBE_EIP_ID" ]; then
        local lbEipLine="- $lbEip $marker (Public)"
      fi
      local lbIpLine="- $lbIp $marker (Private)"
      yq r -d1 $KUBEADM_CONFIG $objPath | (sed "/$marker/d"; echo $lbEipLine; echo $lbIpLine) | yq p - $objPath > $certSansFile
      yq m -x -i -d1 $KUBEADM_CONFIG $certSansFile
      updateApiserverCerts
      reloadKubeMasterProcs
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
  if $KS_ENABLED && isFirstMaster; then runKubectlPatch -n kubesphere-system svc ks-console -p "$(cat /opt/app/current/conf/k8s/ks-console-svc.yml)"; fi
}

reloadKsConf() {
  if $KS_ENABLED && isFirstMaster; then
    runKubectlPatch -n kubesphere-system --type merge cc ks-installer -p "$(buildKsDynamicConf)"
  fi
}

resetAuditingModule() {
  runKubectlPatch -n kubesphere-system --type merge cc ks-installer -p '{"status": {"auditing": null}}'
}

updateHostnicStatus() {
  isUsingHostnic || return 0
  local status=0
  checkHostnicVxnets || status=$?
  rotate $HOSTNIC_STATUS_FILE
  echo -n $status > $HOSTNIC_STATUS_FILE
}

checkHostnicHealthy() {
  isUsingHostnic || return 0
  local statusCode
  statusCode=$(cat $HOSTNIC_STATUS_FILE) || statusCode=$EC_HOSTNIC_VXNETS_UNKNOWN
  return $statusCode
}

reloadHostnic() {
  isUsingHostnic || return 0
  restartSvc hostnic-status
  runKubectl apply -f /opt/app/current/conf/k8s/hostnic-cm.yml
  runKubectl -n kube-system rollout restart ds hostnic-node
}

reloadKubeMasterArgs() {
  if isMaster; then
    initControlPlane $@
    if isFirstMaster; then
      runKubeadm init phase upload-config kubeadm
    fi
  fi
}

reloadKubeApiserverCerts() {
  if isMaster; then updateApiserverCerts; fi
}

reloadKubeMasterProcs() {
  isMaster || return 0
  local component; for component in ${@:-apiserver controller-manager scheduler}; do
    local proc=kube-$component
    kill -s SIGHUP $(pidof $proc) && retry 5 1 0 pidof $proc || log "WARN: failed to SIGHUP to '$proc'."
  done
}

reloadKubeProxy() {
  isFirstMaster || return 0
  runKubeadm init phase upload-config kubeadm
  runKubeadm init phase addon kube-proxy
}

reloadKubeLogLevel() {
  isMaster || return 0
  runKubeadm init phase upload-config kubeadm
  retry 60 1 0 applyKubeProxyLogLevel
  sleep $(( $RANDOM % 5 + 1 ))
  initControlPlane
}

applyKubeProxyLogLevel() {
  local -r type=daemonsets.app name=kube-proxy
  runKubectlPatch -n kube-system $type $name -p "$(runKubectl -n kube-system get $type $name -oyaml | updateLogLevel $name)"
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

labelTopology() {
  runKubectl label no $(getMyNodeName) topology.kubernetes.io/zone="$MY_ZONE" --overwrite
  if [ ! -z "${CLUSTER_REGION}" ]; then
    runKubectl label no $(getMyNodeName) topology.kubernetes.io/region="$CLUSTER_REGION" --overwrite
  fi
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
  if [ "$days" -gt 0 ]; then docker system prune -f --filter "until=$(( $days * 24 ))h"; fi
}

ensureCertsValid() {
  checkCertDaysBeyond 30 || renewCerts
}

checkCertDaysBeyond() {
  test $(getCertValidDays) -gt $1
}

getCertValidDays() {
  local earliestExpireDate; earliestExpireDate="$(runKubeadm certs check-expiration | awk '$1!~/^$|^CERTIFICATE/ {print "date -d\"",$2,$3,$4,$5,"\" +%s" | "/bin/bash"}' | sort -n | head -1)"
  local today; today="$(date +%s)"
  echo -n $(( ($earliestExpireDate - $today) / (24 * 60 * 60) ))
}

renewCerts() {
  local crt; for crt in ${@:-admin.conf apiserver apiserver-kubelet-client controller-manager.conf front-proxy-client scheduler.conf}; do kubeadm  certs renew $crt; done
  reloadKubeMasterProcs
  if isFirstMaster; then distributeKubeConfig; fi
}

fixOverlays() {
  local transientRoot=/var/lib/docker/overlay2
  local persistentRoot=/data/var/lib/docker/overlay2
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
  local kubeLbEip=$(getLbEipFromFile)
  if [ -n "$kubeLbEip" ]; then
    urlAuthority=$kubeLbEip:6443
  elif [ -n "$K8S_API_HOST" ]; then
    urlAuthority=$K8S_API_HOST:$K8S_API_PORT
  else
    urlAuthority="$(hasKubeLb && isClusterInitialized && getLbIpFromFile || getFirstMasterIp):6443"
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

# appctl podnetshoot coredns
podnetshoot() {
  docker run --rm -it --net container:$(docker ps | grep k8s_POD_$1 | head -n 1 | awk '{print $NF}') kubesphere/netshoot:v1.0 bash
}

# appctl podnsenter coredns
podnsenter() {
  nsenter -n -t `docker inspect -f {{.State.Pid}} $(docker ps | grep k8s_POD_$1 | head -n 1 | awk '{ print $1 }')`
}

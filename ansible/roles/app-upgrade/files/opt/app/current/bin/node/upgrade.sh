#!/usr/bin/env bash

set -eo pipefail

prepareUsers() {
  grep -q ^svc: /etc/group || groupadd svc
  local user; for user in $@; do
    grep -q ^$user: /etc/passwd || useradd -r -G svc -d /nonexistent -s /sbin/nologin $user
  done
}

backUpToDir() {
  local cmd=mv
  if [ "$1" = "--keep-old" ]; then
    cmd="cp -r"
    shift
  fi
  mkdir -p $1
  local f; for f in ${@:2}; do
    if test -e $f; then $cmd $f $1; fi
  done
}

extractFiles() {
  rsync -aAX $UPGRADE_DIR/vm-files/ /
  chown -R root.svc /opt/app/
}

backUpFiles() {
  local -r version=$1
  backUpToDir /opt/app/$version/conf/confd/conf.d/ $(find /etc/confd/conf.d -mindepth 1 -maxdepth 1 ! -name cmd.info.toml)
  backUpToDir /opt/app/$version/conf/confd/templates/ $(find /etc/confd/templates -mindepth 1 -maxdepth 1 ! -name cmd.info.tmpl)
  backUpToDir /opt/app/$version/conf/systemd/ /lib/systemd/system/kubelet.service /etc/systemd/system/{etcd.service,kubelet.service.d}
  backUpToDir /opt/crictl/$version/ /usr/bin/crictl
  backUpToDir /opt/etcd/$version/ /usr/bin/{etcd,etcdctl}
  backUpToDir /opt/k8s-node/$version/node/bin/ /usr/bin/{kubeadm,kubectl,kubelet}
  backUpToDir /opt/helm/$version/ /usr/bin/helm
  backUpToDir --keep-old $BACKUP_DIR/$version/ /data/kubernetes/
  backUpToDir --keep-old $BACKUP_DIR/$version/kubelet/ /data/var/lib/kubelet/{config.yaml,kubeadm-flags.env,pki}
  if crontab -l; then crontab -r; fi
}

linkToDir() {
  local f; for f in ${@:2}; do
    if test -e $f; then ln -snf $f $1; fi
  done
}

setUpFiles() {
  ln -snf /opt/app/current/bin/ctl.sh /usr/bin/appctl
  find /opt/app/current/conf/confd/conf.d/ -name '*.toml' -exec ln -snf {} /etc/confd/conf.d/ \;
  find /opt/app/current/conf/confd/templates/ -name '*.tmpl' -exec ln -snf {} /etc/confd/templates/ \;
  linkToDir /usr/bin/ /opt/etcd/current/{etcd,etcdctl} /opt/crictl/current/crictl /opt/k8s-client/current/client/bin/kubectl /opt/k8s-node/current/node/bin/{kubeadm,kubectl,kubelet}
  linkToDir /usr/local/bin/ /opt/helm/current/helm
  find /opt/yq/current/ -name 'yq*' -exec ln -snf {} /usr/bin/yq \;
  find /opt/jq/current/ -name 'jq*' -exec ln -snf {} /usr/bin/jq \;
  systemctl daemon-reload
  /opt/qingcloud/app-agent/bin/confd -onetime || true
  systemctl restart confd
}

cleanUp() {
  rm -rf $UPGRADE_DIR
}

main() {
  . $1/../envs/upgrade.env
  prepareUsers etcd
  extractFiles
  backUpFiles $(date +%y%m%d.%H%M%S)
  setUpFiles
  appctl upgrade
  cleanUp
}

main $(dirname $0)

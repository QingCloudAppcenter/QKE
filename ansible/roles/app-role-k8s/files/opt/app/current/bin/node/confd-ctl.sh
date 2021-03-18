getCgroupDriver() {
  grep -om1 cgroupfs $CGROUP_DRIVER_FILE || echo systemd
}

syncKubeAuditFiles() {
  if [ -f $KUBE_AUDIT_POLICY_RUNTIME_FILE -o "$1" = "--init" ]; then
    rsync $KUBE_AUDIT_POLICY_CHANGED_FILE $KUBE_AUDIT_POLICY_RUNTIME_FILE
    rsync $KUBE_AUDIT_WEBHOOK_CHANGED_FILE $KUBE_AUDIT_WEBHOOK_RUNTIME_FILE
  fi
}

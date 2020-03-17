getCgroupDriver() {
  grep -om1 cgroupfs $CGROUP_DRIVER_FILE || echo systemd
}

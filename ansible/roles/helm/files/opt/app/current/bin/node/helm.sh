defineHELM2() {
  if ${IS_UPGRADING_FROM_V1:-false}; then
    echo "/usr/bin/helm"
  elif ${IS_UPGRADING_FROM_V2:-false}; then
    echo "/opt/helm/2.14.3/helm"
  else
    echo "/opt/helm/2.14.3/helm"
    return
  fi
}

MIGRATE_PLUGIN="2to3"
HELM2="$(defineHELM2)"
HELM3="/opt/helm/$HELM_VERSION/helm"
UPGRADE_HELM_ERR=224
UPGRADE_COMPLETED_FILE="/root/.config/upgrade.completed"

upgradeHelm() {
  [[ -n "$HELM2" ]] || return $UPGRADE_HELM_ERR
  checkPluginExists $MIGRATE_PLUGIN || {
    log "plugin $MIGRATE_PLUGIN not exists"
    return $UPGRADE_HELM_ERR
  }
  if isFirstMaster; then
    migrateConfigures
    migrateReleases
    cleanupOldHelmData
    touch $UPGRADE_COMPLETED_FILE
    local path;for path in /root/{.config,.local,.cache}; do 
      distributeFile $path $STABLE_MASTER_NODES $STABLE_WORKER_NODES $STABLE_CLIENT_NODES
    done
  else
    waitFirstMasterHelmUpgradeCompleted
    rm -rf /root/.helm
  fi
}

checkPluginExists() {
  $HELM3 plugin list |grep $1
}

waitFirstMasterHelmUpgradeCompleted() {
  retry 3600 2 0 checkTillerExists
}

checkTillerExists() {
  [[ -e "$UPGRADE_COMPLETED_FILE" ]] && $HELM2 list |grep "could not find tiller"
}

getAllReleases() {
  $HELM2 list -q
}

migrateRelease() {
  local releaseName=${1?releaseName}
  local action="convert"
  log "migrate release: [$releaseName]"
  local dryRunResult; dryRunResult="$(echo "y" |$HELM3 $MIGRATE_PLUGIN $action $releaseName --dry-run)" && 
    local convertResult; convertResult="$(echo "y" |$HELM3 $MIGRATE_PLUGIN $action $releaseName)" || {
      log "migrate release [$releaseName] fail or permmision denied, dryRunResult: [$dryRunResult] convertResult: [$convertResult]"
      return $UPGRADE_HELM_ERR
    }
  log "migrate release: [$releaseName]"
}

migrateConfigures() {
  log "migrate helm configures"
  local migrateConfiguresResult; migrateConfiguresResult="$(echo "y" |$HELM3 $MIGRATE_PLUGIN move)" || {
    log "migrate helm configures fail, result [$migrateConfiguresResult], return code: $?"
  }
  log "migrate helm configures success, result [$migrateConfiguresResult]"
}

migrateReleases() {
  local allReleases="$(getAllReleases)"
  log "will migreted releases: [$allReleases]"
  local release; for release in $allReleases; do
    [[ -z "$release" ]] || migrateRelease $release
  done
  log "all releases migrate success"
}

cleanupOldHelmData() {
  log "clean up"
  local action="cleanup"
  local dryRunResult; dryRunResult=$(echo "y" |$HELM3 $MIGRATE_PLUGIN $action --dry-run) &&
    local cleanupResult; cleanupResult="$(echo "y" |$HELM3 $MIGRATE_PLUGIN $action)" || {
      log "cleanup failed or permmision denied, dryRunResult: [$dryRunResult], cleanupResult: [$cleanupResult]"
      return $UPGRADE_HELM_ERR
    }
  log "clean up success"
}


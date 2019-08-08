#!/bin/bash
function check_fs_fail {
  echo $1 >&2
  exit 1
}

function check_fs_log {
  logger -t appctl $@
}

function check_fs_wait {
  local n=1
  local max=20
  local delay=2

  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        check_fs_log "Command failed. Attempt $n/$max:"
        sleep $delay;
      else
        check_fs_fail "The command has failed after $n attempts."
      fi
    }
  done
}

check_fs_wait date >> /etc/tmp
check_fs_wait date >> /data/tmp
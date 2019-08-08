#!/bin/bash
function check_env_fail {
  echo $1 >&2
  exit 1
}

function check_env_log {
  logger -t appctl $@
}

function check_env_wait {
  local n=1
  local max=20
  local delay=2

  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        check_env_log "Command failed. Attempt $n/$max:"
        sleep $delay;
      else
        check_env_fail "The command has failed after $n attempts."
      fi
    }
  done
}

check_env_wait cat /data/env.sh > /dev/null
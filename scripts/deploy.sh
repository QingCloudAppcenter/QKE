#!/bin/bash

set +e

appversion=appv-tzssw6ay
WORKSPACE=$(dirname $BASH_SOURCE)

if [ $# -lt 2 ]; then
    echo "Error, not enough parameters"
    exit 1
fi
$WORKSPACE/../bin/appcenter-cli deploy -u $1 -r &appversion -o $2
echo "Deploy done"

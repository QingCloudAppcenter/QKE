#!/bin/bash

set +e

appversion=appv-tzssw6ay
WORKSPACE=$(dirname $BASH_SOURCE)

if [ $# -lt 2 ]; then
    echo "Error, not enough parameters"
    exit 1
fi
$WORKSPACE/../bin/appcenter-cli deploy -u $1 -r $appversion -o $2
echo "Deploy done"

cluster_id=`cat $2`
temp_json=/tmp/cluster.json
while true; do
    $WORKSPACE/../bin/appcenter-cli get-cluster -c $cluster_id -o $temp_json
    status=`cat $temp_json | jq -r .cluster_set[0].status`
    printf "Cluster <%s> is %s now\n" $cluster_id $status
    if [ $status == "active" ]; then
        break
    fi
    sleep 5s
done

echo "DONE"
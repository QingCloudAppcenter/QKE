#!/bin/bash



appversion=appv-tzssw6ay
WORKSPACE=$(dirname $BASH_SOURCE)

if [ -f $WORKSPACE/__CLUSTER_ID ]; then
    echo "Delete exsit cluster"
    $WORKSPACE/delete_cluster.sh
    rm -f $WORKSPACE/__CLUSTER_ID
fi
set -e
if [ $# -lt 2 ]; then
    echo "Error, not enough parameters"
    exit 1
fi
$WORKSPACE/../bin/appcenter-cli deploy -u $1 -r $appversion -o $2


cluster_id=`cat $2`
temp_json=/tmp/cluster.json
while true; do
    $WORKSPACE/../bin/appcenter-cli get-cluster -c $cluster_id -o $temp_json
    status=`cat $temp_json | jq -r .cluster_set[0].status`
    printf "Cluster <%s> is %s now\n" $cluster_id $status
    if [ $status == "active" ]; then
        break
    fi
    sleep 10s
done

echo "Deploy done"
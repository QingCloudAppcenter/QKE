#!/bin/bash
##$1 is module, $2 is config file, $3 is output CLUSTER_ID_FILE
WORKSPACE=$(dirname $BASH_SOURCE)
tempdir=$WORKSPACE/../app/$1/__generated
CLUSTER_ID_FILE="$tempdir/__CLUSTER_ID"

source $WORKSPACE/common.sh
if [ -f $CLUSTER_ID_FILE ]; then
    echo "Delete exsit cluster"
    $WORKSPACE/delete_cluster.sh $1
fi
set -e
if [ -n "$3" ]; then
    CLUSTER_ID_FILE="$3"
fi

$WORKSPACE/../bin/appcenter-cli deploy -u $2 -r $appversion -o $CLUSTER_ID_FILE
cluster_id=`cat $CLUSTER_ID_FILE`
temp_json=$tempdir/cluster.json

##following line will take a bit more time
while true; do
    sleep 10s
    $WORKSPACE/../bin/appcenter-cli get-cluster -c $cluster_id -o $temp_json
    status=`cat $temp_json | jq -r .cluster_set[0].status`
    printf "Cluster <%s> is %s now\n" $cluster_id $status
    if [ $status == "active" ]; then
        break
    fi
done

echo "Deploy done"
#!/bin/bash


WORKSPACE=`dirname $BASH_SOURCE`
cd $WORKSPACE
source ./common.sh

CLUSTER_ID_FILE="../app/$1/__generated/__CLUSTER_ID"

if [ $# -ge 2 ]; then
    ../bin/appcenter-cli delete-cluster -c $2 --cease
    echo "Delete cluster done"
fi
 
if [ -f $CLUSTER_ID_FILE ]; then
    clusterID=`cat $CLUSTER_ID_FILE`
    ../bin/appcenter-cli delete-cluster -c $clusterID --cease
    rm -f $CLUSTER_ID_FILE
fi
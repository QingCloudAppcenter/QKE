#!/bin/bash


WOKRSPACE=`dirname $BASH_SOURCE`
cd $WOKRSPACE
source ./common.sh


if [ -f __CLUSTER_ID ]; then
    clusterID=`cat __CLUSTER_ID`
    ../bin/appcenter-cli delete-cluster -c $clusterID --cease
else
    ../bin/appcenter-cli delete-cluster -c $1 --cease
fi
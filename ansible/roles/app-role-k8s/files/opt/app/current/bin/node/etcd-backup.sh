#!/bin/bash
 
ETCDCTL_PATH='/opt/etcd/3.4.13/etcdctl'
ENDPOINTS='http://127.0.0.1:2379'
ETCD_DATA_DIR="/data/var/lib/etcd"
BACKUP_DIR="/data/backup/etcd-$(date +%Y-%m-%d-%H-%M-%S)"
KEEPBACKUPNUMBER='5'
ETCDBACKUPSCIPT='/opt/app/current/bin/node'
 
[ ! -d $BACKUP_DIR ] && mkdir -p $BACKUP_DIR
 
export ETCDCTL_API=2;$ETCDCTL_PATH backup --data-dir $ETCD_DATA_DIR --backup-dir $BACKUP_DIR
 
sleep 3
 
{
export ETCDCTL_API=3;$ETCDCTL_PATH --endpoints="$ENDPOINTS" snapshot save $BACKUP_DIR/snapshot.db
} > /dev/null
 
sleep 3
 
cd $BACKUP_DIR/../;ls -lt |awk '{if(NR > '$KEEPBACKUPNUMBER'){print "rm -rf "$9}}'|sh
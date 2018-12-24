#/bin/bash

WORKSPACE=$(dirname $BASH_SOURCE)
cd $WORKSPACE
IAAS_CMD="qingcloud iaas"
ZONE=ap2a
SSHKEY=kp-yakyv3g5
MACHINEID=i-50zn6df7
source ./common.sh
WaitUntilDoneOrTimeOut "Detach keypair" $IAAS_CMD detach-keypairs -z $ZONE -k $SSHKEY -i $MACHINEID
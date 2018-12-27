#! /bin/bash

# detect machine exsit
set -e
set -u

if [ $# -lt 2 ]; then
    printf "Not enough arguments,quit\n"
    exit 1
fi

run_script=${1}-run.sh

WORKSPACE=$(dirname $BASH_SOURCE)
cd $WORKSPACE

IAAS_CMD="qingcloud iaas"
IMAGE_ID=$2
INSTANCE_NAME=kubesphere_app_$1
ZONE=ap2a
TIMEOUT=120
VXNET=vxnet-lddzg8e
ROUTE_ID=rtr-gkubu96i
SSHKEY=""
ip=""
source common.sh

function cleanup(){
    echo "Do some dirty work"
    sleep 5s
    set +e
    set +u
    if [ -n $SSHKEY ]; then
        printf "detach sshkey\n"
        WaitUntilDoneOrTimeOut "Detach keypair" $IAAS_CMD detach-keypairs -z $ZONE -k $SSHKEY -i $MACHINEID
        WaitUntilDoneOrTimeOut "Delete SSHKEY"  $IAAS_CMD delete-keypairs -z $ZONE -k $SSHKEY
    fi 
    printf "delete created machine\n"
    WaitUntilDoneOrTimeOut "Delete machine" $IAAS_CMD terminate-instances -z $ZONE -i $MACHINEID -D 1
    exit $1
}
#trap cleanup EXIT
function GetIP(){
    while [ -z $ip ]; do
        ip=`$IAAS_CMD describe-instances -W $MACHINEID -z $ZONE | jq -r .instance_set[0].vxnets[0].private_ip`
        printf "Waiting for machine to get its ip\r"
        sleep 2s
    done
    ip=`Trim $ip`
}

trap cleanup EXIT SIGINT
MACHINEID=`$IAAS_CMD describe-instances -W $INSTANCE_NAME -z $ZONE | jq '.instance_set[]|select(.status=="running")|.instance_id'`
if [ -z $MACHINEID ]; then
    ##create SSH key
    public_key=`cat ~/.ssh/id_rsa.pub`
    ret_json=`$IAAS_CMD create-keypair -z $ZONE -N local-ssh -m user --public_key "$public_key"`

    SSHKEY=`CliDoneOrDie "$ret_json" "create keypair" ".keypair_id"`
    SSHKEY=${SSHKEY//\"/}
    printf "Create SSH-Key %s successful\n" $SSHKEY
    ##create
    ret_json=`$IAAS_CMD run-instances -N $INSTANCE_NAME -m $IMAGE_ID -t c4m8 -n $VXNET -l keypair -k $SSHKEY --hostname k8s-master -z $ZONE`
    MACHINEID=`CliDoneOrDie "$ret_json" "creating instance" ".instances[0]"`
    MACHINEID=`Trim $MACHINEID`
    printf "waiting for %s starting\n" $MACHINEID
    ##wait for starting
    t=0
    while [ $t -lt $TIMEOUT ]; do
        status=`$IAAS_CMD describe-instances -i $MACHINEID -m $IMAGE_ID -z $ZONE | jq -r '.instance_set[0].status'`
        if [ $status == "running" ]; then
            printf "machine %s is %s now\n"  $MACHINEID $status
            break
        fi
        sleep 5s
    done
    if [ $TIMEOUT -le $t ]; then
        echo "Error! Timeout wait for machine running, please check the machine <$MACHINEID> in zone $ZONE"
        exit 1
    fi
    GetIP
    printf "IP Address is %s\n" $ip
    set +e
    ssh-keygen -R $ip
    ssh-keyscan -H $ip >>~/.ssh/known_hosts
    set -e
else
    MACHINEID=`Trim $MACHINEID`
    printf "detect machine %s exsit, skip creating\n" $MACHINEID
    GetIP
fi

#Prepare
ssh root@$ip "mkdir -p /opt/kubernetes/script"
scp -r ../vm-scripts root@$ip:/root/vm-scripts
scp ../app/kubernetes/$1/* root@$ip:/opt/kubernetes/script/
scp -r ../app/bin root@$ip:/opt/kubernetes/bin

ssh root@$ip /bin/bash  << EOF
chmod +x vm-scripts/*.sh  
./vm-scripts/$run_script
rm -rf vm-scripts  
history -c
EOF
$IAAS_CMD stop-instances -z $ZONE -i $MACHINEID
printf "waiting for %s shutting down\n" $MACHINEID
    ##wait for starting
t=0
while [ $t -lt $TIMEOUT ]; do
    status=`$IAAS_CMD describe-instances -i $MACHINEID -m $IMAGE_ID -z $ZONE | jq -r '.instance_set[0].status'`
    if [ $status == "stopped" ]; then
        printf "machine %s is %s now\n"  $MACHINEID $status
        break
    fi
    sleep 5s
    let t=t+5
done
if [ $TIMEOUT -le $t ]; then
    echo "Error! Timeout wait for machine stopped, please check the machine <$MACHINEID> in zone $ZONE"
    exit 1
fi

ret_json=`$IAAS_CMD capture-instance -z $ZONE -i $MACHINEID -N ks-app-$1:$3`
IMAGE_ID=`CliDoneOrDie "$ret_json" "capture instance" ".image_id"`
echo "The image id is ${IMAGE_ID}"
echo $IMAGE_ID > ${1}_image_id
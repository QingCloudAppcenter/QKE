#/bin/bash

## Create Kubesphere Base Image
set -e
set -u

if which qingcloud >/dev/null; then
    echo "detected cli installed"
else
    echo "Error! Please install qingcloud-cli first! type 'pip install qingcloud-cli' to install" 
    exit 1
fi

WOKRSPACE=`dirname $BASH_SOURCE`
cd $WOKRSPACE
source ./common.sh

timestamp=`DateString`
mustcacheFile="../app/config/cluster.json.mustache"
configFile="../app/config/config.json"
#create machine
if [ $# -lt 1 ] || [ $1 != "--no-kvm" ]; then
    ./create_kvm.sh master img-acj1tpkc $timestamp
    #./create_kvm.sh node   img-siy0h6rn $timestamp
    #./create_kvm.sh client img-8begmb7y $timestamp
fi

master=`cat __master_IMAGE_ID`
node=`cat __node_IMAGE_ID`
client=`cat __client_IMAGE_ID`

sed "s/MASTER_IMAGE_REPLACE/$master/g;s/NODE_IMAGE_REPLACE/$node/g;s/NODE_SSD_IMAGE_REPLACE/$node/g;s/LOG_IMAGE_REPLACE/$node/g;s/CLIENT_IMAGE_REPLACE/$client/g" ${mustcacheFile}.tmp >${mustcacheFile}

tarFile="app/app.tar.gz"
appVersion="appv-tzssw6ay"
userID="usr-MRiIUq7M"
#tar
tar zcvf ../$tarFile -C ../app/config/ config.json cluster.json.mustache
#upload app
set +e
while true; do
    echo "Try to upload new configs"
    ../bin/appcenter-cli upload-app -r $appVersion -f ../$tarFile
    if [ $? == 0 ]; then
        break
    else
        echo "Error! Try again"
        sleep 2s
    fi
done
set -e


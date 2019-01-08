#/bin/bash
##$1 represent which module like single,HA-stacked
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

tempdir="../app/$1/__generated/"
if [ ! -d $tempdir ]; then
    mkdir -p $tempdir
fi

timestamp=`DateString`
mustcacheFile="../app/$1/config/cluster.json.mustache"
configFile="../app/$1/config/config.json"
#create machine
##COMMENT some of these line in need
if [ $# -lt 2 ] || [ $2 != "--no-kvm" ]; then
    #./create_kvm.sh $1 master img-tix7p8xg $timestamp
    ./create_kvm.sh $1 node   img-a9zh9jzr $timestamp
    ./create_kvm.sh $1 client img-o9pqapsl $timestamp
fi

master=`cat ../app/$1/__generated/__master_IMAGE_ID`
node=`cat ../app/$1/__generated/__node_IMAGE_ID`
client=`cat ../app/$1/__generated/__client_IMAGE_ID`

sed "s/MASTER_IMAGE_REPLACE/$master/g;s/NODE_IMAGE_REPLACE/$node/g;s/NODE_SSD_IMAGE_REPLACE/$node/g;s/LOG_IMAGE_REPLACE/$node/g;s/CLIENT_IMAGE_REPLACE/$client/g" ${mustcacheFile}.tmp >${mustcacheFile}

tarFile="app/$1/app.tar.gz"
#tar
tar zcvf ../$tarFile -C ../app/$1/config/ config.json cluster.json.mustache
#upload app
set +e
sleep 5s
while true; do
    echo "Try to upload new configs"
    ../bin/appcenter-cli upload-app -r $appversion -f ../$tarFile
    if [ $? == 0 ]; then
        break
    else
        echo "Error! Try to upload again"
        sleep 5s
    fi
done
set -e

echo "New Config files have been uploaded successfully"
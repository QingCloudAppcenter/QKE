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

mustcacheFile="../app/config/cluster.json.mustache"
configFile="../app/config/config.json"
#create machine
#./create_kvm.sh master
#./create_kvm.sh node
#./create_kvm.sh client

master=`cat master_image_id`
node=`cat node_image_id`
client=`cat client_image_id`

sed "s/MASTER_IMAGE_REPLACE/$master/g;s/NODE_IMAGE_REPLACE/$node/g;s/NODE_SSD_IMAGE_REPLACE/$node/g;s/LOG_IMAGE_REPLACE/$node/g;s/CLIENT_IMAGE_REPLACE/$client/g" ${mustcacheFile}.tmp >${mustcacheFile}

#tar
tar zcvf ../app/app.tar.gz -C ../app/config/ config.json cluster.json.mustache




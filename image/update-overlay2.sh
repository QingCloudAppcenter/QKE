 #!/usr/bin/env bash

echo "*************************"
echo "update overlay2"
echo "*************************"

MY_IMAGE_DIR="/opt/overlay2"
DOCKER_IMAGE_DIR="/var/lib/docker/overlay2"

mkdir -p ${MY_IMAGE_DIR}
mv ${DOCKER_IMAGE_DIR}/* ${MY_IMAGE_DIR}
mv ${MY_IMAGE_DIR}/l ${DOCKER_IMAGE_DIR}/
ln -s ${MY_IMAGE_DIR}/* ${DOCKER_IMAGE_DIR}
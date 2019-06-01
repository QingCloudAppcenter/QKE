 #!/usr/bin/env bash

# Copyright 2018 The KubeSphere Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

echo "*************************"
echo "update overlay2"
echo "*************************"

MY_IMAGE_DIR="/opt/overlay2"
DOCKER_IMAGE_DIR="/var/lib/docker/overlay2"

mkdir -p ${MY_IMAGE_DIR}
mv ${DOCKER_IMAGE_DIR}/* ${MY_IMAGE_DIR}
mv ${MY_IMAGE_DIR}/l ${DOCKER_IMAGE_DIR}/
ln -s ${MY_IMAGE_DIR}/* ${DOCKER_IMAGE_DIR}
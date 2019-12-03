#!/usr/bin/env bash

# Copyright 2019 The KubeSphere Authors.
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

SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
K8S_HOME=$(dirname "${SCRIPTPATH}")
SNAPSHOT_DIR="/upgrade"

set -o errexit
set -o nounset
set -o pipefail

# update images
${K8S_HOME}/snapshot/update-image.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update images failed!"
    exit 255
fi

# copy binary
${K8S_HOME}/snapshot/update-binary.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update binary failed!"
    exit 255
fi

# copy scripts
${K8S_HOME}/snapshot/update-script.sh
if [[ $? != 0 ]]
then
    echo "[ERROR]: Update scripts failed!"
    exit 255
fi
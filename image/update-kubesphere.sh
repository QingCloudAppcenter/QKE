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
echo "update kubesphere"
echo "*************************"

KUBESPHERE_INSTALL_PACKAGE="kubesphere-all-advanced-2.0.1-dev-20190604"

pushd /tmp
curl -O -k https://kubesphere-installer.pek3b.qingstor.com/nightly-build/${KUBESPHERE_INSTALL_PACKAGE}.tar.gz
tar -xf ${KUBESPHERE_INSTALL_PACKAGE}.tar.gz -C /opt
mv /opt/${KUBESPHERE_INSTALL_PACKAGE} /opt/kubesphere
rm ${KUBESPHERE_INSTALL_PACKAGE}.tar.gz

popd
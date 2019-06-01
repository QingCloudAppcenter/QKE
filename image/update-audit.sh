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
echo "update audit"
echo "*************************"

if [ ! -d /etc/kubernetes/audit ]
then
  echo "mkdir dir for audit"
  mkdir /etc/kubernetes/audit
fi

cat << EOF > /etc/kubernetes/audit/default-audit-policy-file.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
EOF

if [ -f /etc/kubernetes/audit/default-audit-policy-file.yaml ]
then
  echo "succeed to create audit policy file"
else
  echo "cannot found audit policy file"
fi
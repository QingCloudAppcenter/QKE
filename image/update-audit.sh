#!/usr/bin/env bash

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
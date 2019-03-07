#!/usr/bin/env bash
gitBranch=$1
apt-get install -y git
git clone https://github.com/wnxn/kubesphere-1.git /opt/kubernetes
cd /opt/kubernetes
if [ -n "$gitBranch" ]
then
  git fetch origin $gitBranch:$gitBranch
  git checkout $gitBranch
  git branch --set-upstream-to=origin/$gitBranch $gitBranch
  git pull
fi

# Copy template files
cp -r /opt/kubernetes/confd /etc/confd/
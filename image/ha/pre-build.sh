#!/usr/bin/env bash
gitBranch=$1
apt-get install -y git
git clone https://github.com/QingCloudAppcenter/kubesphere.git /opt/kubesphere
cd /opt/kubesphere
if [ -n "$gitBranch" ]
then
  git fetch origin $gitBranch:$gitBranch
  git checkout $gitBranch
  git branch --set-upstream-to=origin/$gitBranch $gitBranch
  git pull
fi
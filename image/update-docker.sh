#!/usr/bin/env bash

echo "*************************"
echo "update docker"
echo "*************************"

apt-get update

apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common -y

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

apt-get update

apt-get install docker-ce=18.06.2~ce~3-0~ubuntu -y

docker info

apt-mark hold docker-ce
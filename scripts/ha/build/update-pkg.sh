#!/usr/bin/env bash
echo "*************************"
echo "update pkg"
echo "*************************"

apt-get update

apt-get install -y ebtables socat jq apt-transport-https bash-completion ntp wget ca-certificates curl software-properties-common tree

apt-get remove -y network-managerupda

DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

modprobe ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack_ipv4
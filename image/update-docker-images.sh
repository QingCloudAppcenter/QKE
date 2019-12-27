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
echo "update docker images"
echo "*************************"

systemctl start docker

# (2)
docker pull gcr.azk8s.cn/google-containers/hyperkube:v1.15.5
docker pull gcr.azk8s.cn/google-containers/pause:3.1

# Network (7)
docker pull gcr.azk8s.cn/google_containers/coredns:1.3.1
docker pull calico/node:v3.8.4
docker pull calico/cni:v3.8.4
docker pull calico/kube-controllers:v3.8.4
docker pull calico/pod2daemon-flexvol:v3.8.4
docker pull quay.io/coreos/flannel:v0.11.0-amd64
docker pull kubesphere/cloud-controller-manager:v1.4.2

# Storage (6)
docker pull quay.io/k8scsi/csi-provisioner:v1.4.0
docker pull quay.io/k8scsi/csi-attacher:v2.0.0
docker pull quay.io/k8scsi/csi-snapshotter:v1.2.2
docker pull quay.io/k8scsi/csi-resizer:v0.2.0
docker pull csiplugin/csi-qingcloud:v1.1.0
docker pull quay.io/k8scsi/csi-node-driver-registrar:v1.2.0

# tiller (2)
docker pull gcr.azk8s.cn/kubernetes-helm/tiller:v2.12.3
docker pull nginx:1.14-alpine

# kubesphere (10)
docker pull kubesphere/ks-console:v2.1.0
docker pull kubesphere/kubectl:v1.0.0
docker pull kubesphere/ks-account:v2.1.0  
docker pull kubesphere/ks-devops:flyway-v2.1.0  
docker pull kubesphere/ks-apigateway:v2.1.0  
docker pull kubesphere/ks-apiserver:v2.1.0  
docker pull kubesphere/ks-controller-manager:v2.1.0  
docker pull kubesphere/docs.kubesphere.io:advanced-2.0.0  
docker pull kubesphere/cloud-controller-manager:v1.4.0  
docker pull kubesphere/ks-installer:v2.1.0  

# (3)
docker pull quay.azk8s.cn/kubernetes-ingress-controller/nginx-ingress-controller:0.24.1  
docker pull mirrorgooglecontainers/defaultbackend-amd64:1.4 
docker pull gcr.azk8s.cn/google_containers/metrics-server-amd64:v0.3.1 
# (5)
docker pull kubesphere/notification:v2.1.0  
docker pull kubesphere/notification:flyway_v2.1.0  
docker pull kubesphere/alerting-dbinit:v2.1.0  
docker pull kubesphere/alerting:v2.1.0  
docker pull kubesphere/alert_adapter:v2.1.0  
# (4)
docker pull openpitrix/release-app:v0.4.2  
docker pull openpitrix/openpitrix:flyway-v0.4.5  
docker pull openpitrix/openpitrix:v0.4.5  
docker pull openpitrix/runtime-provider-kubernetes:v0.1.2  
# (8)
docker pull kubesphere/jenkins-uc:v2.1.0  
docker pull jenkins/jenkins:2.176.2  
docker pull jenkins/jnlp-slave:3.27-1  
docker pull kubesphere/builder-base:v2.1.0  
docker pull kubesphere/builder-nodejs:v2.1.0  
docker pull kubesphere/builder-maven:v2.1.0  
docker pull kubesphere/builder-go:v2.1.0  
docker pull sonarqube:7.4-community  
# (18)
docker pull kubesphere/s2ioperator:v2.1.0  
docker pull kubesphere/s2irun:v2.1.0  
docker pull kubesphere/java-11-centos7:v2.1.0  
docker pull kubesphere/java-8-centos7:v2.1.0  
docker pull kubesphere/nodejs-8-centos7:v2.1.0  
docker pull kubesphere/nodejs-6-centos7:v2.1.0  
docker pull kubesphere/nodejs-4-centos7:v2.1.0  
docker pull kubesphere/python-36-centos7:v2.1.0  
docker pull kubesphere/python-35-centos7:v2.1.0  
docker pull kubesphere/python-34-centos7:v2.1.0  
docker pull kubesphere/python-27-centos7:v2.1.0  
docker pull kubesphere/tomcat85-java8-centos7:v2.1.0  
docker pull kubesphere/tomcat85-java8-runtime:v2.1.0  
docker pull kubesphere/tomcat85-java11-runtime:v2.1.0  
docker pull kubesphere/tomcat85-java11-centos7:v2.1.0  
docker pull kubesphere/java-8-runtime:v2.1.0  
docker pull kubesphere/java-11-runtime:v2.1.0  
docker pull kubesphere/s2i-binary:v2.1.0  
# (10)
docker pull kubesphere/configmap-reload:v0.0.1  
docker pull kubesphere/prometheus:v2.5.0  
docker pull kubesphere/prometheus-config-reloader:v0.27.1  
docker pull kubesphere/prometheus-operator:v0.27.1  
docker pull kubesphere/kube-rbac-proxy:v0.4.1  
docker pull kubesphere/kube-state-metrics:v1.5.2  
docker pull kubesphere/node-exporter:ks-v0.16.0  
docker pull kubesphere/addon-resizer:1.8.4  
docker pull mirrorgooglecontainers/addon-resizer:1.8.3  
docker pull grafana/grafana:5.2.4  
# (9)
docker pull kubesphere/docker-elasticsearch-curator:5.5.4  
docker pull kubesphere/elasticsearch-oss:6.7.0-1  
docker pull kubesphere/fluent-bit:v1.3.2-reload  
docker pull docker.elastic.co/kibana/kibana-oss:6.7.0 
docker pull dduportal/bats:0.4.0 
docker pull kubesphere/fluentbit-operator:v2.1.0 
docker pull kubesphere/fluent-bit:v1.3.2-reload 
docker pull kubesphere/configmap-reload:v0.0.1 
docker pull kubesphere/log-sidecar-injector:1.0 
# (12)
docker pull istio/kubectl:1.3.3 
docker pull istio/proxyv2:1.3.3 
docker pull istio/citadel:1.3.3 
docker pull istio/pilot:1.3.3 
docker pull istio/mixer:1.3.3 
docker pull istio/galley:1.3.3 
docker pull istio/proxy_init:1.3.3 
docker pull istio/sidecar_injector:1.3.3 
docker pull jaegertracing/jaeger-operator:1.13.1 
docker pull jaegertracing/jaeger-agent:1.13 
docker pull jaegertracing/jaeger-collector:1.13 
docker pull jaegertracing/jaeger-query:1.13 
# (13)
docker pull redis:5.0.5-alpine 
docker pull busybox:1.28.4 
docker pull mysql:8.0.11 
docker pull nginx:1.14-alpine 
docker pull postgres:9.6.8 
docker pull osixia/openldap:1.3.0 
docker pull alpine:3.9 
docker pull haproxy:2.0.4 
docker pull joosthofman/wget:1.0 
docker pull minio/minio:RELEASE.2019-08-07T01-59-21Z 
docker pull minio/minio:RELEASE.2017-12-28T01-21-00Z 
docker pull minio/mc:RELEASE.2019-08-07T23-14-43Z 
docker pull minio/mc:RELEASE.2018-07-13T00-53-22Z 
# (13)
docker pull kubesphere/examples-bookinfo-productpage-v1:1.13.0 
docker pull kubesphere/examples-bookinfo-reviews-v1:1.13.0 
docker pull kubesphere/examples-bookinfo-reviews-v2:1.13.0 
docker pull kubesphere/examples-bookinfo-reviews-v3:1.13.0 
docker pull kubesphere/examples-bookinfo-details-v1:1.13.0 
docker pull kubesphere/examples-bookinfo-ratings-v1:1.13.0
docker pull kubesphere/netshoot:v1.0
docker pull nginxdemos/hello:plain-text
docker pull mysql:8.0.11
docker pull wordpress:4.8-apache
docker pull mirrorgooglecontainers/hpa-example:latest
docker pull java:openjdk-8-jre-alpine
docker pull fluent/fluentd:v1.4.2-2.0
docker pull perl:latest 

systemctl stop docker
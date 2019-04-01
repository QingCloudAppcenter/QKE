#!/usr/bin/env bash

echo "*************************"
echo "update docker images"
echo "*************************"


docker login -u guest -p guest dockerhub.qingcloud.com

# Basic
docker pull dockerhub.qingcloud.com/google_containers/hyperkube-amd64:v1.12.7
docker pull dockerhub.qingcloud.com/google_containers/pause-amd64:3.1

# Network
docker pull dockerhub.qingcloud.com/google_containers/coredns:1.2.6
docker pull dockerhub.qingcloud.com/google_containers/coredns:1.2.2
docker pull dockerhub.qingcloud.com/calico/node:v3.3.3
docker pull dockerhub.qingcloud.com/calico/cni:v3.3.3
docker pull dockerhub.qingcloud.com/calico/kube-controllers:v3.1.3
docker pull dockerhub.qingcloud.com/coreos/flannel:v0.10.0-amd64
docker pull dockerhub.qingcloud.com/qingcloud/qingcloud-cloud-controller-manager:v1.1.3

# QingCloud CSI
docker pull dockerhub.qingcloud.com/k8scsi/csi-provisioner:v0.2.1
docker pull dockerhub.qingcloud.com/k8scsi/csi-attacher:v0.2.0
docker pull dockerhub.qingcloud.com/k8scsi/driver-registrar:v0.2.0
docker pull dockerhub.qingcloud.com/csiplugin/csi-qingcloud:v0.2.1

# KubeSphere
docker pull dockerhub.qingcloud.com/kubesphere/ks-console:advanced-1.0.1
docker pull kubesphere/ks-account:advanced-1.0.1
docker pull kubesphere/ks-apiserver:advanced-1.0.1
docker pull kubesphere/ks-apigateway:advanced-1.0.0
docker pull dockerhub.qingcloud.com/kubesphere/kubectl:advanced-1.0.0
docker pull dockerhub.qingcloud.com/qingcloud/jenkins-uc:0.6.0
docker pull kubesphere/devops:flyway-advanced-1.0.0       
docker pull kubesphere/devops:advanced-1.0.0              
docker pull jenkins/jenkins:2.138.4                     
docker pull dockerhub.qingcloud.com/prometheus/node-exporter:ks-v0.15.3                  
docker pull openpitrix/openpitrix:flyway-v0.3.5               
docker pull openpitrix/openpitrix:v0.3.5                      
docker pull dockerhub.qingcloud.com/coreos/kube-state-metrics:v1.3.2                      
docker pull kubesphere/builder-go:advanced-1.0.0              
docker pull kubesphere/builder-maven:advanced-1.0.0              
docker pull kubesphere/builder-nodejs:advanced-1.0.0              
docker pull kubesphere/builder-base:advanced-1.0.0              
docker pull dockerhub.qingcloud.com/google_containers/coredns:1.2.6                       
docker pull jenkins/jnlp-slave:3.27-1                      
docker pull dockerhub.qingcloud.com/google_containers/cluster-proportional-autoscaler-amd64:1.3.0                       
docker pull osixia/openldap:1.2.2                                           
docker pull dockerhub.qingcloud.com/coreos/prometheus-config-reloader:v0.23.0                     
docker pull dockerhub.qingcloud.com/coreos/prometheus-operator:v0.23.0                     
docker pull mysql:8.0.11                      
docker pull dockerhub.qingcloud.com/coreos/kube-rbac-proxy:v0.3.1                      
docker pull dockerhub.qingcloud.com/prometheus/prometheus:v2.3.1                                            
docker pull busybox:1.28.4                      
docker pull dockerhub.qingcloud.com/kubernetes_helm/tiller:v2.9.1
docker pull dockerhub.qingcloud.com/kubernetes_helm/tiller:v2.11.0
docker pull dockerhub.qingcloud.com/coreos/etcd:v3.2.18                     
docker pull dockerhub.qingcloud.com/coreos/flannel:v0.10.0                     
docker pull minio/minio:RELEASE.2017-12-28T01-21-00Z
docker pull dockerhub.qingcloud.com/google_containers/pause:3.1                         
docker pull googlecontainer/defaultbackend-amd64:1.4                         
docker pull dockerhub.qingcloud.com/google_containers/metrics-server-amd64:v0.2.0                      
docker pull dockerhub.qingcloud.com/coreos/flannel-cni:v0.3.0                      
docker pull dockerhub.qingcloud.com/coreos/configmap-reload:v0.0.1                      
docker pull dockerhub.qingcloud.com/coreos/addon-resizer:1.0                         
docker pull redis:4.0            
docker pull nginx:1.14-alpine    
docker pull docker:18.06.1-ce-dind

# logging
docker pull dockerhub.qingcloud.com/elasticsearch/elasticsearch-oss:6.4.2
docker pull dockerhub.qingcloud.com/kibana/kibana-oss:6.4.2
docker pull dockerhub.qingcloud.com/fluent/fluent-bit:0.14.7
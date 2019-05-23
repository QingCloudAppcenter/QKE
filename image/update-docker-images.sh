#!/usr/bin/env bash

echo "*************************"
echo "update docker images"
echo "*************************"


docker login -u guest -p guest dockerhub.qingcloud.com

# Basic
docker pull dockerhub.qingcloud.com/google_containers/hyperkube:v1.13.5
docker pull dockerhub.qingcloud.com/google_containers/pause:3.1

# Network
docker pull dockerhub.qingcloud.com/google_containers/coredns:1.2.6
docker pull dockerhub.qingcloud.com/google_containers/coredns:1.4.0
docker pull dockerhub.qingcloud.com/calico/typha:v3.3.6
docker pull dockerhub.qingcloud.com/calico/node:v3.3.6
docker pull dockerhub.qingcloud.com/calico/cni:v3.3.6
docker pull dockerhub.qingcloud.com/calico/ctl:v3.1.3
docker pull dockerhub.qingcloud.com/calico/kube-controllers:v3.1.3
docker pull dockerhub.qingcloud.com/coreos/flannel:v0.11.0-amd64
docker pull dockerhub.qingcloud.com/google_containers/cluster-proportional-autoscaler-amd64:1.3.0
docker pull kubesphere/cloud-controller-manager:v1.3.4

# QingCloud CSI
docker pull dockerhub.qingcloud.com/k8scsi/csi-provisioner:v0.2.1
docker pull dockerhub.qingcloud.com/k8scsi/csi-attacher:v0.2.0
docker pull dockerhub.qingcloud.com/k8scsi/driver-registrar:v0.2.0
docker pull dockerhub.qingcloud.com/csiplugin/csi-qingcloud:v0.2.1



# KubeSphere                    
docker pull dockerhub.qingcloud.com/kubernetes_helm/tiller:v2.11.0
docker pull dockerhub.qingcloud.com/kubernetes_helm/tiller:v2.12.3
docker pull dockerhub.qingcloud.com/kubernetes_ingress_controller/nginx-ingress-controller:0.16.2
docker pull googlecontainer/defaultbackend-amd64:1.4
docker pull dockerhub.qingcloud.com/google_containers/metrics-server-amd64:v0.3.1

# others
docker pull nginx
docker pull busybox

# ks_core_images:
docker pull dockerhub.qingcloud.com/kubesphere/ks-console:advanced-2.0.0
docker pull dockerhub.qingcloud.com/kubesphere/kubectl:advanced-1.0.0
docker pull kubesphere/ks-account:advanced-2.0.0
docker pull kubesphere/ks-devops:flyway-advanced-2.0.0
docker pull kubesphere/ks-apigateway:advanced-2.0.0
docker pull kubesphere/ks-apiserver:advanced-2.0.0
docker pull kubesphere/ks-controller-manager:advanced-2.0.0
docker pull kubesphere/docs.kubesphere.io:latest
docker pull kubesphere/ks-upgrade:advanced-2.0.0
docker pull kubesphere/cloud-controller-manager:v1.3.4

# ks_notification_images:

docker pull kubesphere/notification:flyway-advanced-2.0.0
docker pull kubesphere/notification:advanced-2.0.0
docker pull kubesphere/alerting-dbinit:advanced-2.0.0
docker pull kubesphere/alerting:advanced-2.0.0
docker pull kubesphere/alert_adapter:advanced-2.0.0

# openpitrix_images:

docker pull openpitrix/openpitrix:v0.3.5
docker pull openpitrix/openpitrix:flyway-v0.3.5
docker pull minio/minio:RELEASE.2018-09-25T21-34-43Z
docker pull dockerhub.qingcloud.com/coreos/etcd:v3.2.18


# storage_images:
docker pull dockerhub.qingcloud.com/external_storage/nfs-client-provisioner:v3.1.0-k8s1.11

# harbor_images:

docker pull dockerhub.qingcloud.com/goharbor/nginx-photon:v1.7.5git 
docker pull dockerhub.qingcloud.com/goharbor/chartmuseum-photon:v0.8.1-v1.7.5
docker pull dockerhub.qingcloud.com/goharbor/notary-server-photon:v0.6.1-v1.7.5
docker pull dockerhub.qingcloud.com/goharbor/harbor-registryctl:v1.7.5
docker pull dockerhub.qingcloud.com/goharbor/registry-photon:v2.6.2-v1.7.5
docker pull dockerhub.qingcloud.com/goharbor/harbor-jobservice:v1.7.5
docker pull dockerhub.qingcloud.com/goharbor/harbor-portal:v1.7.5
docker pull dockerhub.qingcloud.com/goharbor/harbor-adminserver:v1.7.5
docker pull dockerhub.qingcloud.com/goharbor/harbor-db:v1.7.5
docker pull dockerhub.qingcloud.com/goharbor/clair-photon:v2.0.8-v1.7.5
docker pull dockerhub.qingcloud.com/goharbor/notary-signer-photon:v0.6.1-v1.7.5
docker pull dockerhub.qingcloud.com/goharbor/redis-photon:v1.7.5
docker pull dockerhub.qingcloud.com/goharbor/harbor-core:v1.7.5

# jenkins_images:

docker pull dockerhub.qingcloud.com/qingcloud/jenkins-uc:0.8.0-dev
docker pull jenkins/jenkins:2.138.4
docker pull jenkins/jnlp-slave:3.27-1
docker pull kubesphere/builder-base:advanced-1.0.0
docker pull kubesphere/builder-nodejs:advanced-1.0.0
docker pull kubesphere/builder-maven:advanced-1.0.0
docker pull kubesphere/builder-go:advanced-1.0.0
docker pull docker:18.06.1-ce-dind
docker pull sonarqube:7.4-community

# s2i_images:

docker pull kubesphere/s2ioperator:advanced-2.0.0
docker pull kubesphere/s2irun:advanced-2.0.0
docker pull kubesphere/java-11-centos7:advanced-2.0.0
docker pull kubesphere/java-8-centos7:advanced-2.0.0
docker pull kubesphere/nodejs-8-centos7:advanced-2.0.0
docker pull kubesphere/nodejs-6-centos7:advanced-2.0.0
docker pull kubesphere/nodejs-4-centos7:advanced-2.0.0
docker pull kubesphere/python-36-centos7:advanced-2.0.0
docker pull kubesphere/python-35-centos7:advanced-2.0.0
docker pull kubesphere/python-34-centos7:advanced-2.0.0
docker pull kubesphere/python-27-centos7:advanced-2.0.0

# gitlab_images:

docker pull dockerhub.qingcloud.com/gitlab_org/gitaly:v1.20.0
docker pull dockerhub.qingcloud.com/gitlab_org/gitlab-rails-ce:v11.8.1
docker pull dockerhub.qingcloud.com/gitlab_org/gitlab-shell:v8.4.4
docker pull dockerhub.qingcloud.com/gitlab_org/gitlab-sidekiq-ce:v11.8.1
docker pull gitlab/gitlab-runner:alpine-v10.3.0
docker pull dockerhub.qingcloud.com/gitlab_org/gitlab-task-runner-ce:v11.8.1
docker pull dockerhub.qingcloud.com/gitlab_org/gitlab-unicorn-ce:v11.8.1
docker pull dockerhub.qingcloud.com/gitlab_org/gitlab-workhorse-ce:v11.8.1
docker pull dockerhub.qingcloud.com/gitlab_org/kubectl:1f8690f03f7aeef27e727396927ab3cc96ac89e7
docker pull dockerhub.qingcloud.com/gitlab_org/gitlab-mailroom:0.9.1
docker pull dockerhub.qingcloud.com/gitlab_org/gitlab-redis-ha:732704f18e34ba469df34b10c3b2465e0469d484
docker pull oliver006/redis_exporter:v0.30.0
docker pull wrouesnel/postgres_exporter:v0.1.1
docker pull dockerhub.qingcloud.com/gitlab_org/alpine-certificates:20171114-r3
docker pull dockerhub.qingcloud.com/gitlab_org/cfssl-self-sign:1.2
docker pull dockerhub.qingcloud.com/gitlab_org/gitlab-operator:v0.3
docker pull minio/mc:RELEASE.2018-07-13T00-53-22Z
docker pull registry:2.7.1

# ks_monitor_images:

docker pull dockerhub.qingcloud.com/coreos/configmap-reload:v0.0.1
docker pull dockerhub.qingcloud.com/prometheus/prometheus:v2.5.0
docker pull dockerhub.qingcloud.com/coreos/prometheus-config-reloader:v0.27.0
docker pull dockerhub.qingcloud.com/coreos/prometheus-operator:v0.27.0
docker pull dockerhub.qingcloud.com/coreos/kube-rbac-proxy:v0.4.1
docker pull dockerhub.qingcloud.com/coreos/kube-state-metrics:v1.5.2
docker pull dockerhub.qingcloud.com/prometheus/node-exporter:ks-v0.16.0
docker pull dockerhub.qingcloud.com/coreos/addon-resizer:1.8.4
docker pull dockerhub.qingcloud.com/coreos/k8s-prometheus-adapter-amd64:v0.4.1

# ks_logger_images:

docker pull dockerhub.qingcloud.com/pires/docker-elasticsearch-curator:5.5.4
docker pull dockerhub.qingcloud.com/elasticsearch/elasticsearch-oss:6.7.0
docker pull dockerhub.qingcloud.com/fluent/fluent-bit:0.14.7
docker pull dockerhub.qingcloud.com/kibana/kibana-oss:6.7.0
docker pull dduportal/bats:0.4.0
docker pull kubesphere/fluentbit-operator:advanced-2.0.0
docker pull kubesphere/fluent-bit:advanced-2.0.0
docker pull dockerhub.qingcloud.com/kslogging/configmap-reload:latest

# istio_images:

docker pull docker.io/istio/kubectl:1.1.1
docker pull docker.io/istio/proxy_init:1.1.1
docker pull docker.io/istio/proxyv2:1.1.1
docker pull docker.io/istio/citadel:1.1.1
docker pull docker.io/istio/pilot:1.1.1
docker pull docker.io/istio/mixer:1.1.1
docker pull docker.io/istio/galley:1.1.1
docker pull docker.io/istio/sidecar_injector:1.1.1
docker pull docker.io/istio/node-agent-k8s:1.1.1
docker pull jaegertracing/jaeger-operator:1.11.0
docker pull jaegertracing/jaeger-agent:1.11
docker pull jaegertracing/jaeger-collector:1.11
docker pull jaegertracing/jaeger-query:1.11

# base_images:

docker pull redis:4.0
docker pull busybox:1.28.4
docker pull mysql:8.0.11
docker pull nginx:1.14-alpine
docker pull postgres:9.6.8
docker pull osixia/openldap:1.2.2
docker pull alpine:3.9

# examples_bookinfo_images:

docker pull kubesphere/examples-bookinfo-productpage-v1:1.13.0
docker pull kubesphere/examples-bookinfo-reviews-v1:1.13.0
docker pull kubesphere/examples-bookinfo-reviews-v2:1.13.0
docker pull kubesphere/examples-bookinfo-reviews-v3:1.13.0
docker pull kubesphere/examples-bookinfo-details-v1:1.13.0
docker pull kubesphere/examples-bookinfo-ratings-v1:1.13.0
docker pull nginxdemos/hello:plain-text
docker pull mysql:5.6
docker pull wordpress:4.8-apache
docker pull mirrorgooglecontainers/hpa-example:latest
docker pull java:openjdk-8-jre-alpine
docker pull fluent/fluentd:v1.4.2-2.0
docker pull perl:latest
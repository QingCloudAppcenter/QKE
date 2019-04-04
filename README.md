# 简介
[KubeSphere](https://kubesphere.io/) 是 QingCloud 开发的基于 Kubernetes 的开源企业级多租户容器平台。 通过 QingCloud AppCenter 能够为用户快速搭建 KubeSphere 环境。此 App 是基于 Kubernetes v1.12.7 预装了 KubeSphere Advanced Edition v1.0.1。

# 特点

1. 支持 3 Master 高可用部署和 1 Master 部署
2. 预装 [QingCloud CSI v0.2.1](https://github.com/yunify/qingcloud-csi) 存储插件，支持动态分配基于 QingCloud 云平台硬盘的存储卷。
3. 预装 [QingCloud 负载均衡器插件 v1.1.3](https://github.com/yunify/qingcloud-cloud-controller-manager)，支持通过 LB 方式将应用暴露出集群。
4. 支持修改参数
5. 支持外接 Etcd App 集群。
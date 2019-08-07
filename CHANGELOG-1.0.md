<!-- BEGIN MUNGE: GENERATED_TOC -->
- [v1.0.1](#v101)
    - [Changelog since v1.0.1](#changelog-since-v101)
        - [Features](#features)
        - [Bug Fixed](#bug-fixed)
<!-- END MUNGE: GENERATED_TOC -->

<!-- NEW RELEASE NOTES ENTRY -->

# v1.0.1
## Changelog since v1.0.1
### Features

* Improve KubeSphere console URL when updating KubeSphere console ([#52](https://github.com/QingCloudAppcenter/QKE/pull/52/files), [@wnxn](https://github.com/wnxn))
* Forbid to set QingCloud image registry as registry mirror ([#62](https://github.com/QingCloudAppcenter/QKE/pull/62), [@wnxn](https://github.com/wnxn))
* Autoscale node in a QKE cluster ([#58](https://github.com/QingCloudAppcenter/QKE/pull/58), [@zheng1](https://github.com/zheng1))
* Remove parameters about private image registry ([#63](https://github.com/QingCloudAppcenter/QKE/pull/63), [@wnxn](https://github.com/wnxn))
* Rename resource group ([#67](https://github.com/QingCloudAppcenter/QKE/pull/67), [@wnxn](https://github.com/wnxn))
* Install KubeSphere only v2.0.2 ([#68](https://github.com/QingCloudAppcenter/QKE/pull/68), [@wnxn](https://github.com/wnxn))
* Remove Harbor and Gitlab images from KVM ([#68](https://github.com/QingCloudAppcenter/QKE/pull/68), [@wnxn](https://github.com/wnxn))
* Add NeonSAN storage class at supported zone ([#75](https://github.com/QingCloudAppcenter/QKE/pull/75), [@wnxn](https://github.com/wnxn))
* Access Kubernetes through EIP ([#75](https://github.com/QingCloudAppcenter/QKE/pull/75), [@wnxn](https://github.com/wnxn))
* Add installation KubeSphere option ([#75](https://github.com/QingCloudAppcenter/QKE/pull/75), [@wnxn](https://github.com/wnxn))
* Add regex in insecure regitry ([#75](https://github.com/QingCloudAppcenter/QKE/pull/75), [@wnxn](https://github.com/wnxn))
* Install arping ([#82](https://github.com/QingCloudAppcenter/QKE/pull/91), [@wnxn](https://github.com/wnxn))
* Remove images with latest tag ([#90](https://github.com/QingCloudAppcenter/QKE/pull/90), [@wnxn](https://github.com/wnxn))
* Add NFS client provisioner helm chart ([#89](https://github.com/QingCloudAppcenter/QKE/pull/89), [@wnxn](https://github.com/wnxn))
* Update Cloud Controller Manager to v1.3.5 ([#114](https://github.com/QingCloudAppcenter/QKE/pull/114), [@wnxn](https://github.com/wnxn))
* Add node affinity on ks docs and prometheus ([#112](https://github.com/QingCloudAppcenter/QKE/pull/112), [@wnxn](https://github.com/wnxn))
* Display Kubeconfig on QingCloud console ([#108](https://github.com/QingCloudAppcenter/QKE/pull/108), [@wnxn](https://github.com/wnxn))
* Restart control plane after renewing certs ([#110](https://github.com/QingCloudAppcenter/QKE/pull/110), [@wnxn](https://github.com/wnxn))
* Enable kube adn system reserved resource ([#105](https://github.com/QingCloudAppcenter/QKE/pull/105), [@wnxn](https://github.com/wnxn))

### Bug fixed
* Fix updating KVM to Ubuntu 18.04.1 LTS 64 bit(bionic1x64c) ([#60](https://github.com/QingCloudAppcenter/QKE/pull/60), [@wnxn](https://github.com/wnxn))
* Fix installing Ceph RBD, Glusterfs, NFS client ([#53](https://github.com/QingCloudAppcenter/QKE/pull/53), [@wnxn](https://github.com/wnxn))
* Fix supporting '-' in hosts domain regex ([#66](https://github.com/QingCloudAppcenter/QKE/pull/66), [@wnxn](https://github.com/wnxn))
* Fix updating max pods on nodes ([#86](https://github.com/QingCloudAppcenter/QKE/pull/86), [@wnxn](https://github.com/wnxn))
* Fix keep log day not working ([#89](https://github.com/QingCloudAppcenter/QKE/pull/89), [@wnxn](https://github.com/wnxn))
* Fix renewing Apiserver certification after updating Kubernetes EIP ([#94](https://github.com/QingCloudAppcenter/QKE/pull/94), [@wnxn](https://github.com/wnxn))
* Fix audit log file path regex ([#95](https://github.com/QingCloudAppcenter/QKE/pull/95), [@wnxn](https://github.com/wnxn))
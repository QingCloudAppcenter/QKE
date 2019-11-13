package clustermustache

const (
	QKEClusterMustache = `{
        "name": {{"{{cluster.name}}"}},
        "description": {{"{{cluster.description}}"}},
        "vxnet": {{"{{cluster.vxnet}}"}},
        "links": {
            "etcd_service": {{"{{cluster.etcd_service}}"}},
            "elk_service": {{"{{cluster.elk_service}}"}}
        },
        "nodes": [
            {
                "role": "master",
                "container": {
                    "type": "kvm",
                    "image": "{{ .KVMImageID }}",
                    "zone": "{{ .KVMImageZone }}"
                },
                "instance_class": {{"{{cluster.master.instance_class}}"}},
                "count": {{"{{cluster.master.count}}"}},
                "cpu": {{"{{cluster.master.cpu}}"}},
                "memory": {{"{{cluster.master.memory}}"}},
                "extra_quota": {
                    "volume": {
                      "size": 230,
                      "count": 14
                    },
                    "loadbalancer": 2,
                    "security_group": 2
                },
                "passphraseless": "ssh-rsa",
                "vertical_scaling_policy": "sequential",
                "volume": {
                    "size": {{"{{cluster.master.volume_size}}"}},
                    "mount_point": "/data",
                    "mount_options": "defaults,noatime",
                    "filesystem": "ext4"
                }{{if eq false .EmptyMode }},
				"services": {
                    "init": {
                        "order": {{ .MasterService.Init.Order }},
                        "cmd": "{{ .MasterService.Init.Cmd }}",
                        "timeout": {{ .MasterService.Init.Timeout }}
                    },
                    "start": {
                        "order": {{ .MasterService.Start.Order }},
                        "cmd": "{{ .MasterService.Start.Cmd }}",
                        "timeout": {{ .MasterService.Start.Timeout }}
                    },
                    "stop": {
                        "cmd": "{{ .MasterService.Stop.Cmd }}",
                        "timeout": {{ .MasterService.Stop.Timeout }}
                    },
                    "destroy": {
                        "order": {{ .MasterService.Destroy.Order }},
                        "nodes_to_execute_on": {{ .MasterService.Destroy.NodeToExecuteOn }},
                        "post_stop_service": {{ .MasterService.Destroy.PostStopService }},
                        "cmd": "{{ .MasterService.Destroy.Cmd }}"
                    },
                    "scale_in":{
                        "nodes_to_execute_on": {{ .MasterService.ScaleIn.NodeToExecuteOn }},
                        "cmd": "{{ .MasterService.ScaleIn.Cmd }}",
                        "timeout": {{ .MasterService.ScaleIn.Timeout }}
                    }
                },
                "custom_metadata": {
                    "cmd": "/opt/kubernetes/script/get-kubeadm-token.sh"
                },
                "health_check": {
                    "enable": true,
                    "interval_sec": 60,
                    "timeout_sec": 10,
                    "action_timeout_sec": 30,
                    "healthy_threshold": 3,
                    "unhealthy_threshold": 3,
                    "check_cmd": "/opt/kubernetes/script/check-master.sh",
                    "action_cmd": "/opt/kubernetes/script/restart-master.sh"
                },
                "monitor": {
                    "enable": true,
                    "cmd": "/opt/kubernetes/script/prom2json  -insecure https://localhost:10250/metrics",
                    "items": {
                        "kubelet_running_container_count": {
                            "unit": "",
                            "value_type": "int",
                            "statistics_type": "latest",
                            "scale_factor_when_display": 0.001
                        },
                        "kubelet_running_pod_count": {
                            "unit": "",
                            "value_type": "int",
                            "statistics_type": "latest",
                            "scale_factor_when_display": 0.001
                        }
                    },
                    "groups": {
                        "kubelet": ["kubelet_running_pod_count","kubelet_running_container_count"]
                    },
                    "display": ["kubelet"],
                    "alarm": ["kubelet_running_container_count"]
                }{{end}}
            },
            {
                "role": "node_std",
                "container": {
                    "type": "kvm",
                    "image": "{{ .KVMImageID }}",
                    "zone": "{{ .KVMImageZone }}"
                },
                "instance_class": 101,
                "count": {{"{{cluster.node_std.count}}"}},
                "cpu": {{"{{cluster.node_std.cpu}}"}},
                "memory": {{"{{cluster.node_std.memory}}"}},
                "passphraseless": "ssh-rsa",
                "volume": {
                    "size": {{"{{cluster.node_std.volume_size}}"}},
                    "mount_point": "/data",
                    "mount_options": "defaults,noatime",
                    "filesystem": "ext4"
                }{{if eq false .EmptyMode }},
				"services": {
                    "init": {
                        "order": {{ .NodeService.Init.Order }},
                        "cmd": "{{ .NodeService.Init.Cmd }}",
                        "timeout": {{ .NodeService.Init.Timeout }}
                    },
                    "start": {
                        "order": {{ .NodeService.Start.Order }},
                        "cmd": "{{ .NodeService.Start.Cmd }}",
                        "timeout": {{ .NodeService.Start.Timeout }}
                    },
                    "stop": {
                        "cmd": "{{ .NodeService.Stop.Cmd }}",
                        "timeout": {{ .NodeService.Stop.Timeout }}
                    }
                },
                "health_check": {
                    "enable": true,
                    "interval_sec": 60,
                    "timeout_sec": 10,
                    "action_timeout_sec": 30,
                    "healthy_threshold": 3,
                    "unhealthy_threshold": 3,
                    "check_cmd": "/opt/kubernetes/script/check-node.sh",
                    "action_cmd": "/opt/kubernetes/script/restart-node.sh"
                },
                "monitor": {
                "enable": true,
                "cmd": "/opt/kubernetes/script/prom2json  -insecure https://localhost:10250/metrics",
                "items": {
                    "kubelet_running_container_count": {
                        "unit": "",
                        "value_type": "int",
                        "statistics_type": "latest",
                        "scale_factor_when_display": 0.001
                    },
                    "kubelet_running_pod_count": {
                        "unit": "",
                        "value_type": "int",
                        "statistics_type": "latest",
                        "scale_factor_when_display": 0.001
                    }
                },
                "groups": {
                    "kubelet": ["kubelet_running_pod_count","kubelet_running_container_count"]
                },
                "display": ["kubelet"],
                "alarm": ["kubelet_running_container_count"]
                },
                "advanced_actions": ["scale_horizontal"]{{end}}
            },
            {
                "role": "node_ent1",
                "container": {
                    "type": "kvm",
                    "image": "{{ .KVMImageID }}",
                    "zone": "{{ .KVMImageZone }}"
                },
                "instance_class": 201,
                "count": {{"{{cluster.node_ent1.count}}"}},
                "cpu": {{"{{cluster.node_ent1.cpu}}"}},
                "memory": {{"{{cluster.node_ent1.memory}}"}},
                "passphraseless": "ssh-rsa",
                "volume": {
                    "size": {{"{{cluster.node_ent1.volume_size}}"}},
                    "mount_point": "/data",
                    "mount_options": "defaults,noatime",
                    "filesystem": "ext4"
                }{{if eq false .EmptyMode }},
                "services": {
                    "init": {
                        "order": {{ .NodeService.Init.Order }},
                        "cmd": "{{ .NodeService.Init.Cmd }}",
                        "timeout": {{ .NodeService.Init.Timeout }}
                    },
                    "start": {
                        "order": {{ .NodeService.Start.Order }},
                        "cmd": "{{ .NodeService.Start.Cmd }}",
                        "timeout": {{ .NodeService.Start.Timeout }}
                    },
                    "stop": {
                        "cmd": "{{ .NodeService.Stop.Cmd }}",
                        "timeout": {{ .NodeService.Stop.Timeout }}
                    }
                },
                "health_check": {
                    "enable": true,
                    "interval_sec": 60,
                    "timeout_sec": 10,
                    "action_timeout_sec": 30,
                    "healthy_threshold": 3,
                    "unhealthy_threshold": 3,
                    "check_cmd": "/opt/kubernetes/script/check-node.sh",
                    "action_cmd": "/opt/kubernetes/script/restart-node.sh"
                },
                "monitor": {
                    "enable": true,
                    "cmd": "/opt/kubernetes/script/prom2json  -insecure https://localhost:10250/metrics",
                    "items": {
                        "kubelet_running_container_count": {
                            "unit": "",
                            "value_type": "int",
                            "statistics_type": "latest",
                            "scale_factor_when_display": 0.001
                        },
                        "kubelet_running_pod_count": {
                            "unit": "",
                            "value_type": "int",
                            "statistics_type": "latest",
                            "scale_factor_when_display": 0.001
                        }
                    },
                    "groups": {
                        "kubelet": ["kubelet_running_pod_count","kubelet_running_container_count"]
                    },
                    "display": ["kubelet"],
                    "alarm": ["kubelet_running_container_count"]
                },
                "advanced_actions": ["scale_horizontal"]{{end}}
            },
            {
                "role": "client",
                "container": {
                    "type": "kvm",
                    "image": "{{ .KVMImageID }}",
                    "zone": "{{ .KVMImageZone }}"
                },
                "instance_class": {{"{{cluster.client.instance_class}}"}},
                "count": 1,
                "cpu": {{"{{cluster.client.cpu}}"}},
                "memory": {{"{{cluster.client.memory}}"}},
                "user_access": true,
                "passphraseless": "ssh-rsa"{{if eq false .EmptyMode }},
                "services": {
                    "init": {
                        "order": {{ .ClientService.Init.Order }},
                        "cmd": "{{ .ClientService.Init.Cmd }}",
                        "timeout": {{ .ClientService.Init.Timeout }}
                    },
                    "start": {
                        "order": {{ .ClientService.Start.Order }},
                        "cmd": "{{ .ClientService.Start.Cmd }}",
                        "timeout": {{ .ClientService.Start.Timeout }}
                    }
                },
                "custom_metadata": {
                    "cmd": "/opt/kubernetes/script/get-loadbalancer-ip.sh"
                }{{end}}
            }
        ],
        "endpoints": {
            "nodeport": {
              "port": {{"{{env.cluster_port_range}}"}},
              "protocol": "tcp"
            },
            "apiserver": {
              "port": 6443,
              "protocol": "tcp"
            }
          },
        "env": {
            "access_key_id": {{"{{env.access_key_id}}"}},
            "pod_subnet": {{"{{env.pod_subnet}}"}},
            "service_subnet": {{"{{env.service_subnet}}"}},
            "api_external_domain": {{"{{env.api_external_domain}}"}},
            "cluster_port_range": {{"{{env.cluster_port_range}}"}},
            "max_pods": {{"{{env.max_pods}}"}},
            "network_plugin": {{"{{env.network_plugin}}"}},
            "proxy_mode": {{"{{env.proxy_mode}}"}},
            "host_aliases": {{"{{env.host_aliases}}"}},
            "registry_mirrors": {{"{{env.registry_mirrors}}"}},
            "insecure_registry": {{"{{env.insecure_registry}}"}},
            "docker_bip": {{"{{env.docker_bip}}"}},
            "keep_log_days": {{"{{env.keep_log_days}}"}},
            "kube_audit_file": {{"{{env.kube_audit_file}}"}},
            "keep_audit_days": {{"{{env.keep_audit_days}}"}},
            "docker_prune_days": {{"{{env.docker_prune_days}}"}},
            "kube_log_level": {{"{{env.kube_log_level}}"}},
            "master_count": {{"{{cluster.master.count}}"}},
            "kubesphere_eip": {{"{{env.kubesphere_eip}}"}},
            "kubernetes_eip": {{"{{env.kubernetes_eip}}"}},
            "install_kubesphere": {{"{{env.install_kubesphere}}"}},
            "kubernetes_version": "{{ .KubernetesVersion }}"
        },
        "display_tabs": {
            "kubesphere_console": {
                "cmd": "/opt/kubernetes/script/get-ks-console-url-json.sh",
                "roles_to_execute_on": ["master"],
                "description": "Get KubeSphere Console",
                "timeout": 10
            },
            "Kubeconfig":{
                "cmd": "/opt/kubernetes/script/get-kubeconfig-content-json.sh",
                "roles_to_execute_on": ["master"],
                "description": "Get Kubeconfig",
                "timeout": 10
            }
        }
}
`
)

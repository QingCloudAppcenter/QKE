package clustermustache

import (
	"github.com/wnxn/QKE/pkg/constant"
	"github.com/wnxn/QKE/pkg/util"
)

type Service struct {
	Init     ServiceCommand
	Start    ServiceCommand
	Stop     ServiceCommand
	ScaleOut ServiceCommand
	ScaleIn  ServiceCommand
	Restart  ServiceCommand
	Destroy  ServiceCommand
	Upgrade  ServiceCommand
}

type ServiceCommand struct {
	Order            int
	Cmd              string
	NodeToExecuteOn  int
	PostStopService  bool
	PostStartService bool
	Timeout          int
}

type ClusterMustacheParameters struct {
	KubernetesVersion string
	EmptyMode         bool
	KVMImageID        string
	KVMImageZone      string
	MasterService     Service
	NodeService       Service
	ClientService     Service
}

func NewClusterMustacheParameters(kvmId, kvmZone string, enableEmptyMode bool) *ClusterMustacheParameters {
	return &ClusterMustacheParameters{
		KubernetesVersion: constant.KubernetesVersion,
		EmptyMode:         enableEmptyMode,
		KVMImageID:        kvmId,
		KVMImageZone:      kvmZone,
		MasterService: Service{
			Init: ServiceCommand{
				Order:   2,
				Cmd:     "/opt/kubernetes/script/init-master.sh",
				Timeout: 1200,
			},
			Start: ServiceCommand{
				Order:   1,
				Cmd:     "/opt/kubernetes/script/start-master.sh",
				Timeout: 1200,
			},
			Stop: ServiceCommand{
				Cmd:     "/opt/kubernetes/script/stop-master.sh",
				Timeout: 1200,
			},
			Destroy: ServiceCommand{
				Order:           1,
				Cmd:             "/opt/kubernetes/script/destroy-master.sh",
				NodeToExecuteOn: 1,
				PostStopService: false,
			},
			ScaleIn: ServiceCommand{
				Cmd:             "/opt/kubernetes/script/scale-in.sh",
				NodeToExecuteOn: 1,
				Timeout:         86400,
			},
		},
		NodeService: Service{
			Init: ServiceCommand{
				Order:   2,
				Cmd:     "/opt/kubernetes/script/init-node.sh",
				Timeout: 1200,
			},
			Start: ServiceCommand{
				Order:   2,
				Cmd:     "/opt/kubernetes/script/start-node.sh",
				Timeout: 1200,
			},
			Stop: ServiceCommand{
				Cmd:     "/opt/kubernetes/script/stop-node.sh",
				Timeout: 1200,
			},
		},
		ClientService: Service{
			Init: ServiceCommand{
				Order:   1,
				Cmd:     "/opt/kubernetes/script/init-client.sh",
				Timeout: 1200,
			},
			Start: ServiceCommand{
				Order:   3,
				Cmd:     "/opt/kubernetes/script/start-client.sh",
				Timeout: 1200,
			},
		},
	}
}

func GetClusterMustache(param *ClusterMustacheParameters) ([]byte, error) {
	return util.ParseTemplate(QKEClusterMustache, param)
}

package configjson

import "github.com/wnxn/QKE/pkg/util"

type ConfigJsonParameters struct {
	EtcdAppId string
	ELKAppId  string
}

func NewDefaultConfigJsonParameters() *ConfigJsonParameters {
	return &ConfigJsonParameters{
		EtcdAppId: "",
		ELKAppId:  "",
	}
}

func GetConfigJson(param *ConfigJsonParameters) ([]byte, error) {
	return util.ParseTemplate(QKEConfigJson, param)
}

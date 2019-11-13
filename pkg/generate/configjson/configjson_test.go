package configjson

import "testing"

func TestGetConfigJson(t *testing.T) {
	tests := []struct {
		EtcdId string
		ELKId  string
	}{
		{
			EtcdId: "test-etcd-id",
			ELKId:  "test-elk-id",
		},
	}
	for _, test := range tests {
		cfg := NewDefaultConfigJsonParameters()
		cfg.EtcdAppId = test.EtcdId
		cfg.ELKAppId = test.ELKId
		bytes, err := GetConfigJson(cfg)
		if err != nil {
			t.Errorf("GetConfigJson err: %s", err)
		}
		t.Logf("%s", bytes)
	}
}

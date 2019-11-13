package clustermustache

import "testing"

func TestGetClusterMustache(t *testing.T) {

	tests := []struct {
		param *ClusterMustacheParameters
	}{
		{
			param: NewClusterMustacheParameters("fake-id", "fake-zone", false),
		},
		//{
		//	param: NewClusterMustacheParameters("fake-id", "fake-zone", true),
		//},
	}
	for _, test := range tests {
		_, err := GetClusterMustache(test.param)
		if err != nil {
			t.Errorf("GetClusterMustache err: %s", err)
		}
	}
}

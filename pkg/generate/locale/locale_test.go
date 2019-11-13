package locale

import "testing"

func TestGetConfigJson(t *testing.T) {
	_, err := GetLocal()
	if err != nil {
		t.Errorf("GetConfigJson err: %s", err)
	}
}

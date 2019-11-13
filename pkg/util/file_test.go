package util

import (
	"io"
	"os"
	"path"
	"reflect"
	"testing"
)

func TestCreateFileWithBytes(t *testing.T) {
	content := []byte("TestCreateFileWithBytesj")
	pathElem := []string{"./tmp", "config", "a.txt"}
	filePath := path.Join(pathElem...)
	err := CreateFileWithBytes(content, pathElem...)

	//defer os.RemoveAll(path.Dir(filepath))
	if err != nil {
		t.Errorf("CreateFileWithBytes failed, error: %s", err)
	}
	f, err := os.Open(filePath)
	defer f.Close()
	if err != nil {
		t.Errorf("Open %s error: %s", filePath, err.Error())
	}

	read := make([]byte, len(content))
	_, err = io.ReadFull(f, read)
	if err != nil {
		t.Errorf("Read %s error: %s", filePath, err.Error())
	}
	if !reflect.DeepEqual(content, read) {
		t.Errorf("%s != %s", string(content), string(read))
	}
}

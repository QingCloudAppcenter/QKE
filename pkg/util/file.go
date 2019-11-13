package util

import (
	"fmt"
	"github.com/pkg/errors"
	"k8s.io/klog"
	"os"
	"path"
)

func CreateFileWithBytes(bytes []byte, elem ...string) error {
	filePath := path.Join(elem...)
	klog.Infof("filepath %s", filePath)
	err := os.MkdirAll(path.Dir(filePath), 0777)
	if err != nil {
		return errors.Wrapf(err, "failed to create directory %s", path.Dir(filePath))
	}
	f, err := os.Create(filePath)
	defer f.Close()
	if err != nil {
		return errors.Wrapf(err, "failed to create filename %s", filePath)
	}
	_, err = fmt.Fprintf(f, "%s", bytes)
	if err != nil {
		return errors.Wrapf(err, "failed to write filename %s", filePath)
	}
	return nil
}

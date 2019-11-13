package main

import (
	"fmt"
	"github.com/wnxn/QKE/cmd/qkeadm/app"
	"k8s.io/klog"
	"os"
)

func main() {
	klog.InitFlags(nil)
	if err := app.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
	os.Exit(0)
}

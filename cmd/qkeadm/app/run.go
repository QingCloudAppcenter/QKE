package app

import (
	"github.com/spf13/pflag"
	"github.com/wnxn/QKE/cmd/qkeadm/app/cmd"
	cliflag "k8s.io/component-base/cli/flag"
	"os"
)

func Run() error {
	pflag.CommandLine.SetNormalizeFunc(cliflag.WarnWordSepNormalizeFunc)
	pflag.Set("logtostderr", "true")
	// We do not want these flags to show up in --help
	// These MarkHidden calls must be after the lines above
	pflag.CommandLine.MarkHidden("version")
	pflag.CommandLine.MarkHidden("log-flush-frequency")
	pflag.CommandLine.MarkHidden("alsologtostderr")
	pflag.CommandLine.MarkHidden("log-backtrace-at")
	pflag.CommandLine.MarkHidden("log-dir")
	pflag.CommandLine.MarkHidden("logtostderr")
	pflag.CommandLine.MarkHidden("stderrthreshold")
	pflag.CommandLine.MarkHidden("vmodule")
	cmd := cmd.NewQkeadmCommand(os.Stdin, os.Stdout, os.Stderr)
	return cmd.Execute()
}

package cmd

import (
	"github.com/spf13/cobra"
	"io"
)

func NewQkeadmCommand(in io.Reader, out, err io.Writer) *cobra.Command {
	cmds := &cobra.Command{
		Use:   "qkeadm",
		Short: "qkeadm: easily develop a QKE",
	}

	cmds.ResetFlags()

	cmds.AddCommand(NewCmdGenerate(out))
	return cmds
}

package cmd

import (
	"github.com/pkg/errors"
	"github.com/spf13/cobra"
	"github.com/wnxn/QKE/pkg/constant"
	"github.com/wnxn/QKE/pkg/generate/clustermustache"
	"github.com/wnxn/QKE/pkg/generate/configjson"
	"github.com/wnxn/QKE/pkg/generate/locale"
	"github.com/wnxn/QKE/pkg/util"
	"io"
)

func NewCmdGenerate(out io.Writer) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "generate",
		Short: "Generate config directory with files",
	}
	cmd.AddCommand(NewCmdGenerateConfigJson(out))
	cmd.AddCommand(NewCmdGenerateClusterMustache(out))
	cmd.AddCommand(NewCmdGenerateConfigDir(out))
	return cmd
}

// NewCmdGenerateConfigJson writes down config.json
// Parameters:
//  - etcdapp
//  - elkapp
func NewCmdGenerateConfigJson(out io.Writer) *cobra.Command {
	cfg := configjson.NewDefaultConfigJsonParameters()
	var configDir string
	cmd := &cobra.Command{
		Use:   "configjson",
		Short: "Write down config.json file",
		RunE: func(cmd *cobra.Command, args []string) error {
			bytes, err := configjson.GetConfigJson(cfg)
			if err != nil {
				return errors.Wrapf(err, "failed to get %s content", constant.ConfigJsonFileName)
			}
			return util.CreateFileWithBytes(bytes, configDir, constant.ConfigJsonFileName)
		},
	}
	cmd.Flags().StringVar(&cfg.EtcdAppId, "etcdapp", "app-fdyvu2wk", "The Etcd App ID for QKE")
	cmd.Flags().StringVar(&cfg.ELKAppId, "elkapp", "app-p6au3oyq", "The ELK App ID for QKE")
	cmd.Flags().StringVar(&configDir, "dir", "./config", "The directory to write down files")
	return cmd
}

func NewCmdGenerateClusterMustache(out io.Writer) *cobra.Command {
	cfg := clustermustache.NewClusterMustacheParameters("", "", false)
	var configDir string
	cmd := &cobra.Command{
		Use:   "mustache",
		Short: "Write down cluster.mustache.json file",
		RunE: func(cmd *cobra.Command, args []string) error {
			bytes, err := clustermustache.GetClusterMustache(cfg)
			if err != nil {
				return errors.Wrapf(err, "failed to get %s content", constant.ClusterMustacheFileName)
			}
			return util.CreateFileWithBytes(bytes, configDir, constant.ClusterMustacheFileName)
		},
	}
	cmd.Flags().StringVar(&cfg.KVMImageID, "kvmid", "", "The KVM image ID for QKE")
	cmd.Flags().StringVar(&cfg.KVMImageZone, "kvmzone", "", "The KVM image zone for QKE")
	cmd.Flags().BoolVar(&cfg.EmptyMode, "enableemptymode", false, "Enable empty service script")
	cmd.Flags().StringVar(&configDir, "dir", "./config", "The directory to write down files")
	return cmd
}

func NewCmdGenerateConfigDir(out io.Writer) *cobra.Command {
	jsonCfg := configjson.NewDefaultConfigJsonParameters()
	mustacheCfg := clustermustache.NewClusterMustacheParameters("", "", false)
	var configDir string
	cmd := &cobra.Command{
		Use:   "configdir",
		Short: "Write down all config files into one directory",
		RunE: func(cmd *cobra.Command, args []string) error {
			// Get config.json
			bytes, err := configjson.GetConfigJson(jsonCfg)
			if err != nil {
				return errors.Wrapf(err, "failed to get %s content", constant.ConfigJsonFileName)
			}
			if err := util.CreateFileWithBytes(bytes, configDir, constant.ConfigJsonFileName); err != nil {
				return errors.Wrapf(err, "failed to CreateFileWithBytes %s", constant.ConfigJsonFileName)
			}

			// Get mustache
			bytes, err = clustermustache.GetClusterMustache(mustacheCfg)
			if err != nil {
				return errors.Wrapf(err, "failed to get %s content", constant.ClusterMustacheFileName)
			}
			if err := util.CreateFileWithBytes(bytes, configDir, constant.ClusterMustacheFileName); err != nil {
				return errors.Wrapf(err, "failed to CreateFileWithBytes %s", constant.ClusterMustacheFileName)
			}

			// Get locale
			bytes, err = locale.GetLocal()
			if err != nil {
				return errors.Wrapf(err, "failed to get %s locale", constant.LocaleJsonFileName)
			}
			if err := util.CreateFileWithBytes(bytes, configDir, "locale", constant.LocaleJsonFileName); err != nil {
				return errors.Wrapf(err, "failed to CreateFileWithBytes %s", constant.LocaleJsonFileName)
			}
			return nil
		},
	}
	cmd.Flags().StringVar(&jsonCfg.EtcdAppId, "etcdapp", "app-fdyvu2wk", "The Etcd App ID for QKE")
	cmd.Flags().StringVar(&jsonCfg.ELKAppId, "elkapp", "app-p6au3oyq", "The ELK App ID for QKE")
	cmd.Flags().StringVar(&mustacheCfg.KVMImageID, "kvmid", "", "The KVM image ID for QKE")
	cmd.Flags().StringVar(&mustacheCfg.KVMImageZone, "kvmzone", "", "The KVM image zone for QKE")
	cmd.Flags().BoolVar(&mustacheCfg.EmptyMode, "enableemptymode", false, "Enable empty service script")
	cmd.Flags().StringVar(&configDir, "dir", "./config", "The directory to write down files")
	return cmd
}

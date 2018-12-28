// Copyright © 2018 NAME HERE <EMAIL ADDRESS>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package cmd

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"

	"github.com/spf13/cobra"
	"github.com/yunify/qingcloud-sdk-go/service"
)

// getClusterCmd represents the getCluster command
var getClusterCmd = &cobra.Command{
	Use:   "get-cluster",
	Short: "A brief description of your command",
	Long: `A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	Run: getCluster,
}
var clusterId string
var outputJSON string

func init() {
	getClusterCmd.Flags().StringVarP(&clusterId, "cluster-id", "c", "", "The cluster id")
	getClusterCmd.Flags().StringVarP(&outputJSON, "output", "o", "", "Path of output json file")
	getClusterCmd.MarkFlagRequired("cluster-id")
	rootCmd.AddCommand(getClusterCmd)
}

func getCluster(cmd *cobra.Command, args []string) {
	app := GetAppService()
	i := &service.DescribeAPPClustersInput{
		Clusters: []*string{&clusterId},
	}
	o, err := app.DescribeAPPClusters(i)
	if err != nil {
		fmt.Println("[Error]" + err.Error())
		os.Exit(1)
	}
	if *o.RetCode != 0 {
		fmt.Println("[Error]" + *o.Message)
		os.Exit(1)
	}
	if outputJSON != "" {
		bytes, err := json.Marshal(o)
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}
		ioutil.WriteFile(outputJSON, bytes, 0660)
	}
}

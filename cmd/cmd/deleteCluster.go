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
	"fmt"
	"os"

	"github.com/yunify/qingcloud-sdk-go/service"

	"github.com/spf13/cobra"
)

// deleteClusterCmd represents the deleteCluster command
var deleteClusterCmd = &cobra.Command{
	Use:   "delete-cluster",
	Short: "A brief description of your command",
	Long: `A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	Run: deleteCluster,
}

var isCease bool

func init() {
	deleteClusterCmd.Flags().StringVarP(&clusterId, "cluser-id", "c", "", "ID of the cluster")
	deleteClusterCmd.Flags().BoolVar(&isCease, "cease", false, "if delete the cluster directly without going to recycle")
	deleteClusterCmd.MarkFlagRequired("cluster-id")
	rootCmd.AddCommand(deleteClusterCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// deleteClusterCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// deleteClusterCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}
func deleteCluster(cmd *cobra.Command, args []string) {
	i := &service.DeleteAPPClusterInput{
		Clusters: []*string{&clusterId},
	}
	if isCease {
		var cease = 1
		i.DirectCease = &cease
	}
	app := GetAppService()
	output, err := app.DeleteAPPCluster(i)
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
	if *output.RetCode != 0 {
		fmt.Println("Error! Message" + *output.Message)
		os.Exit(1)
	}
	fmt.Println("Delete Cluster succeed")
}

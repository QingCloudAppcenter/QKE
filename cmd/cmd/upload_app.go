package cmd

import (
	"encoding/base64"
	"fmt"
	"io/ioutil"
	"os"
	"path"

	"github.com/spf13/cobra"
	"github.com/yunify/qingcloud-sdk-go/service"
)

var (
	Path string
)

func init() {
	uploadAPPCmd.Flags().StringVarP(&Path, "filepath", "f", "", "The path of configs archive")
	uploadAPPCmd.MarkFlagRequired("resource_id")
	uploadAPPCmd.MarkFlagRequired("filepath")
	uploadAPPCmd.MarkFlagFilename("filepath")
	rootCmd.AddCommand(uploadAPPCmd)
}

var uploadAPPCmd = &cobra.Command{
	Use:   "upload-app",
	Short: "upload configs to appcenter",
	Long:  `All software has versions. This is Hugo's`,
	Run: func(cmd *cobra.Command, args []string) {

		ap2aapp := GetAppService()
		//get detail of appversion
		o, err := describeVersion(resourceID, ap2aapp)
		if err != nil {
			fmt.Println("Error in getting infomation of appversion,err is:" + err.Error())
			os.Exit(1)
		}
		option, err := generateUploadInput()
		if err != nil {
			fmt.Println(err.Error())
			os.Exit(1)
		}
		attachment, err := ap2aapp.UploadCommonAttachment(option)
		if err != nil {
			fmt.Println(err.Error())
			os.Exit(1)
		}
		modify := generateModifyInput(o.VersionSet[0], attachment.AttachmentID)
		resp, err := ap2aapp.ModifyAppVersion(modify)
		if err != nil {
			fmt.Println("[Error]" + err.Error())
			os.Exit(1)
		}
		if *resp.RetCode != 0 {
			fmt.Println("[Error]" + *resp.Message)
			os.Exit(1)
		}
	},
}

func generateUploadInput() (*service.UploadCommonAttachmentInput, error) {
	input := &service.UploadCommonAttachmentInput{}
	input.ResourceID = &resourceID
	fileExt := path.Ext(Path)
	switch fileExt {
	case ".gz":
		fileExt = "tar" + fileExt
	default:
		fileExt = fileExt[1:]
	}
	input.Filext = &fileExt
	filename := path.Base(Path)
	input.Filename = &filename
	file, err := os.Open(Path)
	if err != nil {
		fmt.Println("Error when open file")
		return nil, err
	}
	bytes, _ := ioutil.ReadAll(file)
	content := base64.StdEncoding.EncodeToString(bytes)
	input.AttachmentContent = &content
	return input, nil
}

func describeVersion(versionId string, s *service.AppService) (*service.DescribeAppDevVersionsOutput, error) {
	ids := []*string{&versionId}
	i := &service.DescribeAppDevVersionsInput{
		VersionIDs: ids,
	}
	o, err := s.DescribeAppDevVersions(i)
	if err != nil {
		return nil, err
	}
	return o, err
}

func generateModifyInput(version *service.AppVersion, attachmentId *string) *service.ModifyAppVersionInput {
	i := &service.ModifyAppVersionInput{
		ResourceKit: attachmentId,
		VersionID:   version.VersionID,
		AppID:       version.AppID,
		Name:        version.Name,
		Description: version.Description,
		Prices:      version.Prices,
	}
	return i
}

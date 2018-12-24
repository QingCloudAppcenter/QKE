package main

import (
	"encoding/base64"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"path"

	"github.com/yunify/qingcloud-sdk-go/config"
	"github.com/yunify/qingcloud-sdk-go/service"
)

var (
	h          bool
	Owner      string
	ResourceID string
	Path       string
)

func init() {
	flag.BoolVar(&h, "h", false, "this help")
	flag.StringVar(&Owner, "O", "", "The owner id")
	flag.StringVar(&ResourceID, "R", "", "The resource id")
	flag.StringVar(&Path, "f", "", "the path of archive")
	flag.Usage = usage
}
func main() {
	flag.Parse()

	if h {
		flag.Usage()
		return
	}
	c, _ := config.NewDefault()
	c.LoadUserConfig()
	qcService, err := service.Init(c)
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
	ap2aapp, _ := qcService.App(c.Zone)
	option, err := generateInput()
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
	ret, err := ap2aapp.UploadCommonAttachment(option)
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
	fmt.Println("OK")
	fmt.Println(ret.Message)
}
func generateInput() (*service.UploadCommonAttachmentInput, error) {
	input := &service.UploadCommonAttachmentInput{}
	input.ResourceID = &ResourceID
	input.Owner = &Owner
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
func usage() {
	fmt.Fprintf(os.Stderr, `Upload setting files to qingcloud appcenter, create by magicsong
	Usage: cmd -O ownerid -R resourceID -f filepath
	`)
	flag.PrintDefaults()
}

package main

import (
  "flag"
  "fmt"
  "os"
  qcconfig "github.com/yunify/qingcloud-sdk-go/config"
  qcservice "github.com/hlwanghl/qingcloud-sdk-go/service"
)

func main() {
  cfgFile := flag.String("f", "", "config file")
  zone := flag.String("z", "", "zone")
  listenerId := flag.String("s", "", "load balancer listener ID")
  listenerScene := flag.Int("e", 0, "load balancer listener scene")
  flag.Parse()

  fmt.Fprintf(os.Stderr, "loading configuration file [%s] ...\n", *cfgFile)
  defaultCfg, _ := qcconfig.NewDefault()
  _ = defaultCfg.LoadConfigFromFilepath(*cfgFile)
  qcService, _ := qcservice.Init(defaultCfg)
  lbService, _ := qcService.LoadBalancer(*zone)

  fmt.Fprintf(os.Stderr, "updating scene to [%d] of listener [%s] ...\n", *listenerScene, *listenerId)
  _, err := lbService.ModifyLoadBalancerListenerAttributes(
    &qcservice.ModifyLoadBalancerListenerAttributesInput{
      LoadBalancerListener: qcservice.String(*listenerId),
      Scene: qcservice.Int(*listenerScene),
    },
  )
  if err != nil {
    fmt.Fprintln(os.Stderr, err)
    os.Exit(1)
  }
}

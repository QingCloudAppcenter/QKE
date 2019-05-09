 #!/usr/bin/env bash

echo "*************************"
echo "update helm"
echo "*************************"

 wget  https://kubernetes-helm.pek3b.qingstor.com/linux-amd64/v2.11.0/helm
 chmod +x helm
 mv helm /usr/bin/
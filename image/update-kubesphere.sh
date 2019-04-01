 #!/usr/bin/env bash

echo "*************************"
echo "update kubesphere"
echo "*************************"

pushd /tmp
wget -c https://kubesphere-app.pek3b.qingstor.com/kubesphere-charts/kubesphere-chart-advanced-1.0.1-beta1.tar.gz
tar -zxvf kubesphere-chart-advanced-1.0.1-beta1.tar.gz -C /opt
mv /opt/kubesphere-chart-advanced-1.0.1 /opt/kubesphere
rm kubesphere-chart-advanced-1.0.1-beta1.tar.gz

popd
 #!/usr/bin/env bash

echo "*************************"
echo "update kubesphere"
echo "*************************"

KUBESPHERE_INSTALL_PACKAGE="kubesphere-chart-advanced-1.0.1-beta2.tar.gz"

pushd /tmp
wget -c https://kubesphere-app.pek3b.qingstor.com/kubesphere-charts/${KUBESPHERE_INSTALL_PACKAGE}
tar -zxvf ${KUBESPHERE_INSTALL_PACKAGE} -C /opt
mv /opt/kubesphere-chart-advanced-1.0.1 /opt/kubesphere
rm ${KUBESPHERE_INSTALL_PACKAGE}

popd
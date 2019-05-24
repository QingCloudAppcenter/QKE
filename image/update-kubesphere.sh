 #!/usr/bin/env bash

echo "*************************"
echo "update kubesphere"
echo "*************************"

KUBESPHERE_INSTALL_PACKAGE="kubesphere-all-advanced-2.0.0-dev-20190524.tar.gz"

pushd /tmp
curl -O -k https://kubesphere-installer.pek3b.qingstor.com/nightly-build/kubesphere-all-advanced-2.0.0-dev-20190524.tar.gz
tar -xf ${KUBESPHERE_INSTALL_PACKAGE} -C /opt
mv /opt/kubesphere-all-advanced-2.0.0-dev-20190524 /opt/kubesphere
rm ${KUBESPHERE_INSTALL_PACKAGE}

popd
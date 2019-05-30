 #!/usr/bin/env bash

echo "*************************"
echo "update kubesphere"
echo "*************************"

KUBESPHERE_INSTALL_PACKAGE="kubesphere-all-advanced-2.0.0-20190530"

pushd /tmp
curl -O -k https://kubesphere-installer.pek3b.qingstor.com/nightly-build/${KUBESPHERE_INSTALL_PACKAGE}.tar.gz
tar -xf ${KUBESPHERE_INSTALL_PACKAGE}.tar.gz -C /opt
mv /opt/${KUBESPHERE_INSTALL_PACKAGE} /opt/kubesphere
rm ${KUBESPHERE_INSTALL_PACKAGE}.tar.gz

popd
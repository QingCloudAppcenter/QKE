 #!/usr/bin/env bash

echo "*************************"
echo "update kubesphere"
echo "*************************"

KUBESPHERE_INSTALL_PACKAGE="advanced-2.0.0.tar.gz"

pushd /tmp
curl -L https://kubesphere.io/download/stable/advanced-2.0.0 > ${KUBESPHERE_INSTALL_PACKAGE}
tar -xf ${KUBESPHERE_INSTALL_PACKAGE} -C /opt
mv /opt/kubesphere-all-advanced-2.0.0 /opt/kubesphere
rm ${KUBESPHERE_INSTALL_PACKAGE}

popd
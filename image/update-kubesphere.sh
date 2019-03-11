 #!/usr/bin/env bash

echo "*************************"
echo "update kubesphere"
echo "*************************"

curl -o /opt/kubesphere-chart-1.0.1-test.tar.gz -O -k https://139.198.5.33/test/kubesphere-chart-1.0.1-test.tar.gz -u kubesphere:hcie@123 
tar -xf /opt/kubesphere-chart-1.0.1-test.tar.gz -C /opt
mv /opt/kubesphere-chart-1.0.1 /opt/kubesphere
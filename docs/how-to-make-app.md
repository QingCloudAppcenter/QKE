# 青云k8s app简单指引

1. 创建应用

进入<https://appcenter.qingcloud.com/developer>创建应用，创建应用完成之后创建一个版本，记住版本ID，在后续CI/CD中有用。版本ID是诸如`appv-tzssw6ay`的字符串。创建的应用在没有审核之前都是Dev应用，在后台的API中可以看到，但是这部分API并没有写出来。
2. 准备应用的基础镜像。

基础镜像是整个应用的关键，它的好坏决定了应用的好坏。创建一个基础镜像的步骤通常是：
    1. 建立一个主机
    2. 执行一些需要用的脚本，比如拉取镜像，安装必要软件，复制必要脚本。
    3. 清理工作。比如删掉不需要的文件，删掉访问历史。

下面例举一下我的例子。为了镜像制作的快，可以在亚太区建立主机，这样方便。k8s需要master节点，client节点和node节点（在App center上还有SSD节点），这里只介绍master部分。其他可以参考我的脚本[create_kvm.sh](https://github.com/QingCloudAppcenter/kubesphere/blob/master/scripts/create_kvm.sh)。

1. 建立主机之后，SSH进去，然后创建一些必要的文件夹
```bash
mkdir -p /opt/kubernetes/script
```
2. Exit主机,复制一些脚本到这台主机。对应的文件都在这个repo下（在根目录下执行下面这些命令，下同）
```bash
scp -r vm-scripts root@$ip:/root/vm-scripts
scp app/kubernetes/$1/* root@$ip:/opt/kubernetes/script/
scp -r app/bin root@$ip:/opt/kubernetes/bin
```    
3. 用SSH命令执行在这个镜像要做的工作。（下面中的run_script变量在master镜像中对应[master_run.sh](https://github.com/QingCloudAppcenter/kubesphere/blob/master/vm-scripts/master-run.sh)）
```bash
ssh root@$ip /bin/bash  << EOF
chmod +x /opt/kubernetes/script/*
chmod +x  /opt/kubernetes/bin/*
chmod +x vm-scripts/*.sh  
./vm-scripts/$run_script
rm -rf vm-scripts  
history -c
EOF
```
4. 所有命令完成之后，就可以关机了。关机完成之后在控制台中将这个主机保存为镜像。记录这个镜像的ID，在后续中需要用到。按照相同的步骤，将client镜像和node镜像都做好。不同镜像的差异在于上面的`$run_script`不同。

至此，创建镜像就完成了。有了镜像之后还需要配置文件。

3. 创建配置文件

配置文件的创建可以参考[官网链接](https://docs.qingcloud.com/appcenter/docs/specifications/basic-specifications.html)，本文只用到了两个关键配置文件，本地化还没有考虑。
+ `Config.json`：主要用于告诉前端需要哪些参数，以及集群的一些主机配置
+ `cluster.json.mustache`:主要用于告诉平台如何操作这个集群，比如启动时执行什么脚本，获取监控用什么脚本，升级用什么脚本。这里也可以定义主机的角色，不同角色的主机所配套的脚本不一样，比如k8s中，master节点和node节点的启动逻辑就完全不一样。

这两个文件可以配置很多信息，这里我没有多加研究，只是复用了其他项目的一份配置文件。`config.json`可以直接复用，cluster.json.mustache可以通过下面的命令生成：
```
sed "s/MASTER_IMAGE_REPLACE/$master/g;s/NODE_IMAGE_REPLACE/$node/g;s/NODE_SSD_IMAGE_REPLACE/$node/g;s/LOG_IMAGE_REPLACE/$node/g;s/CLIENT_IMAGE_REPLACE/$client/g" ${mustcacheFile}.tmp >${mustcacheFile}

```
这个命令通过替换模板中的镜像ID来达到生成配置文件的目的，上面的命令使用时需要将一些命令进行替换，比如将$master替换成上面生成的image id等等。可以参考一下[app](https://github.com/QingCloudAppcenter/kubesphere/tree/master/app)这个文件夹下文件。两个文件都完成之后，用tar进行打包：
```bash
tar zcvf $tarFile -C app/config/ config.json cluster.json.mustache
```
打包完成之后，打开AppCenter开发的控制台，进入一开始创建的版本，将这个tar包上传上去，如果上传成功，那么一个应用的开发就完成了。

4. 部署应用

进入<https://console.qingcloud.com/ap2a/apps/develop/>页面，点击页面中的部署实例，就会跳出一个页面，进行参数的配置。这些参数是根据`config.json`生成的，可以做很多的定制，这里就不介绍了。填完参数点击部署，这样一个集群实例就完成了。等待集群起来，进入<https://appcenter.qingcloud.com/developer>，选择应用之后，进入日志tab，路径应该类似<https://appcenter.qingcloud.com/developer/app/app-zm6mxikp/logs>查看日志，如果最新的日志显示都是成功，说明部署成功了。然后可以SSH进集群的master节点看看k8s是否真的起来了，如果有失败，则需要进集群查看日志（日志搜集需要自己在Shell脚本中实现，请参考<https://github.com/QingCloudAppcenter/kubesphere/blob/master/app/kubernetes/master/master_init.sh>）,一旦定位到问题，就可以重新生成镜像，生成配置文件，部署。

5. 注意事项

+ 镜像中必须安装app agent，可以参考vm_scripts文件夹中内容。
+ 重新生成镜像，上传配置文件，需要将之前应用的集群都删掉，回收站清空
+ 日志要自己写代码收集，AppCenter不保存日志。
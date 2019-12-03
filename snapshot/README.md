# 格式化硬盘

## 寻找设备
```
fdisk -l
/dev/vdc
```

## 分区

```
parted /dev/vdc
mklabel gpt
mkpart primary 0 -1
print
quit
```

## 格式化
```
mkfs.ext4 /dev/vdc
mount /dev/vdc /upgrade
```

# 拷贝数据

```
/opt/kubernetes/snapshot/build-base.sh
```

# 制作快照

```
umount /dev/vdc
qingcloud iaas detach-volumes -z sh1a -v vol-owfayvx2 -i i-5k23tqid -f /root/qingcloud.yaml
qingcloud iaas create-snapshots -r vol-owfayvx2 -F 1 -m qcow2 -f /root/qingcloud.yaml
```

```
vi qingcloud.yaml
qy_access_key_id: 'ACCESS_KEY_ID'
qy_secret_access_key: 'ACCESS_KEY_SECRET'
zone: 'ZONE'
host: 'api.qingcloud.com'
port: 443
protocol: 'https'
uri: '/iaas'
```
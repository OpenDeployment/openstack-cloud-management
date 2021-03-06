#!/bin/bash

#hostname="centos7-x"
hostname=""
nic_cur_names="eno16777728 eno33554952"
nic_names="eth0 eth1"

nic_names=${nic_names:-'eth0'}

if [ ! -z "$hostname" ]; then
    hostnamectl set-hostname "$hostname"
fi

# set proxy
cat > /etc/environment << EOF
http_proxy=http://172.30.240.5:3128
https_proxy=http://172.30.240.5:3128
EOF

source /etc/environment

# enable the command ifconfig
yum update -y
yum install -y net-tools tcpdump vim

# disable the predictable naming rule
sed -i 's#GRUB_CMDLINE_LINUX="rd.lvm.lv=centos/root#GRUB_CMDLINE_LINUX="net.ifnames=0 rd.lvm.lv=centos/root#g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

# change nic naming style from enoxxxxx to ethxx
i=0
IFS=" "
for nic_cur_name in $nic_cur_name; do
    nic_name=${nic_names:$i:1}
    if [ -e "/etc/sysconfig/network-scripts/ifcfg-$nic_cur_name" ] && [ ! -e "/etc/sysconfig/network-scripts/ifcfg-$nic_name" ]; then
        mv "/etc/sysconfig/network-scripts/ifcfg-$nic_cur_name" "/etc/sysconfig/network-scripts/ifcfg-$nic_name"
    fi
    sed -i "s#$nic_cur_name#$nic_name#g" "/etc/sysconfig/network-scripts/ifcfg-$nic_name"
    ((i+=2))
done


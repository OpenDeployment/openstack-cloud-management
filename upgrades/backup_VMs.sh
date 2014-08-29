#!/bin/bash
set -x

ENVIRONMENT='/root/openrc'

if [ -e $ENVIRONMENT ];then
    source $ENVIRONMENT
fi

backup_flavor()
{
    echo "begin backup flavor"
    nova flavor-list | sed '1,3d' | sed '$d' > ./$tenant_id/flavor_backup
    echo "backup flavor success"
}

backup_instances()
{
    echo "begin backup instances"
    nova list | sed '1,5d' | sed '$d' > ./$tenant_id/tmp_vm_info
    > ./$tenant_id/instances_backup
    while read line
    do
        vm_id=$(echo $line | awk -F '|' '{print $2}' | tr -d " ")
        name=$(echo $line | awk -F '|' '{print $3}' | tr -d " ")
        network=$(echo $line | awk -F '|' '{print $5}' | tr -d " ")
        flavor=$(nova show $vm_id | grep flavor | awk -F '|' '{print $3}' | awk '{print $1}' | tr -d " ")
        echo $vm_id"|"$name"|"$flavor"|"$network >> ./$tenant_id/instances_backup
    done < ./$tenant_id/tmp_vm_info

    rm -f ./$tenant_id/tmp_vm_info
    echo "backup instances success"
}


backup_network()
{
    echo "begin backup network"
    quantum net-list | sed '1,3d' | sed '$d' > ./tmp_network_info
    > ./network_backup
    while read line
    do
        network_id=$(echo $line | awk -F '|' '{print $2}' | tr -d " ")
        if [ -z "$network_id" ];then
            network_id=$pre_network_id
            network_name=$pre_network_name
        else
            network_name=$(echo $line | awk -F '|' '{print $3}' | tr -d " ")
        fi
        subnet=$(echo $line | awk -F '|' '{print $4}' | tr -d " ")
        is_public=$(quantum net-show $network_id | grep 'router:external' | awk -F "|" '{print $3}' |tr -d " ")
        echo $network_id"|"$network_name"|"$subnet"|"$is_public >> ./network_backup
        pre_network_id=$network_id
        pre_network_name=$network_name
    done < ./tmp_network_info
#    rm -f ./tmp_network_info
    echo "backup network success"
}

backup_tenant()
{
    echo "begin backup tenant"
    keystone tenant-list | sed '1,3d' | sed '$d' > ./tenant_backup
    echo "backup tenant success"
}

backup_floatingip()
{
    echo "begin floatingip tenant"
    quantum floatingip-list | sed '1,3d' | sed '$d' > ./floatingip_backup
    echo "backup floatingip success"
}


main()
{
    #1.backup tenant,??admin???,???????
    #backup_tenant

    #2.backup flavor 
#    backup_flavor
      
    #3.backup network,??admin???,???????
    backup_network

    #4.backup floating ip,??admin???,???????
    #backup_floatingip
    
    #5.backup instances
   #backup_instances
}

if [ $# -ne 3 ];then
  echo "Usage:$0 tenant user passwd"  
  exit 1
fi
tenant=$1
user=$2
passwd=$3
export OS_TENANT_NAME=$tenant
export OS_USERNAME=$user
export OS_PASSWORD=$passwd
tenant_id=$(keystone tenant-list | grep "\<$tenant" | awk -F "|" '{print $2}' | tr -d " ")
if [ -z "${tenant_id}" ];then
    echo "the user password is wrong or the tenant:$tenant does not exist!"
    exit 1
fi
if [ ! -e  ./${tenant_id} ]; then
  mkdir ./${tenant_id}
fi

main

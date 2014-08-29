#!/bin/bash

ENVIRONMENT='/root/openrc'

if [ -e $ENVIRONMENT ];then
    export $ENVIRONMENT
fi

restore_flavor()
{
    echo "begin restore flavor"
    while read line
    do 
        id=$(echo $line | awk -F '|' '{print $2}' | tr -d " ")
        name=$(echo $line | awk -F '|' '{print $3}' | tr -d " ")
        nova   flavor-show $name  > /dev/null 2>&1
        if [ $? -eq 0 ];then
            continue
        fi
        memory=$(echo $line | awk -F '|' '{print $4}' | tr -d " ")
        disk=$(echo $line | awk -F '|' '{print $5}' | tr -d " ")
        ephemeral=$(echo $line | awk -F '|' '{print $6}' | tr -d " ")
        swap=$(echo $line | awk -F '|' '{print $7}' | tr -d " ")
        cpu=$(echo $line | awk -F '|' '{print $8}' | tr -d " ")
        rxtx_factor=$(echo $line | awk -F '|' '{print $9}' | tr -d " ")
        is_public=$(echo $line | awk -F '|' '{print $10}' | tr -d " ")
        if [ -z "$swap" ];then
           nova flavor-create --ephemeral $ephemeral --rxtx-factor $rxtx_factor --is-public $is_public  $name $id $memory $disk $cpu > /dev/null 2>&1
        else
           nova flavor-create --ephemeral $ephemeral --swap $swap --rxtx-factor $rxtx_factor --is-public $is_public  $name $id $memory $disk $cpu > /dev/null 2>&1
        fi
    done < ./${tenant_id}/flavor_backup
    echo "restore flavor success"
}

restore_network()
{
    echo "begin restore network"
    while read line
    do 
        id=$(echo $line | awk -F '|' '{print $1}'| tr -d " ")
        name=$(echo $line | awk -F '|' '{print $2}' | tr -d " ")
        subnet_info=$(echo $line | awk -F '|' '{print $3}' | awk '{print $2}')
        is_public=$(echo $line | awk -F '|' '{print $4}' | tr -d " ")
        neutron net-show $name > /dev/null 2>&1
        if [ $? -eq 0 ];then
            neutron subnet-create $name $subnet_info > /dev/null 2>&1
        else
            if [ "$is_public" = "True" ];then
                neutron  net-create $name --router:external=true > /dev/null 2>&1
            else
                neutron  net-create $name > /dev/null 2>&1
            fi
            neutron subnet-create $name $subnet_info > /dev/null 2>&1
        fi
    done < ./${tenant_id}/network_backup 
    echo "restore network success"
}

restore_instances()
{
    echo "begin restore instances"
    while read line
    do
        vm_id=$(echo $line | awk -F '|' '{print $1}' | tr -d " ")
        name=$(echo $line | awk -F '|' '{print $2}' | tr -d " ")
        flavor=$(echo $line | awk -F '|' '{print $3}' | tr -d " ")
        network_info=$(echo $line | awk -F '|' '{print $4}' | tr -d " ")
        nova show $name > /dev/null 2>&1
        if [ $? -eq 0 ];then
            continue
        fi
        nic_info=""
        for net in $(echo $network_info | sed "s/;/ /g");
        do
            network_name=$(echo $net | awk -F "=" '{print $1}')
            network_id=$(neutron net-show $network_name |  grep "\<id" | awk -F "|" '{print $3}' | tr -d " ")
            ips=$(echo $net | awk -F "=" '{print $2}')
            for ip in $(echo $ips |sed "s/,/ /g");
            do
                nic_info=$nic_info"--nic net-id=$network_id,v4-fixed-ip=$ip "
            done                
         done
         nova boot --flavor $flavor --image $vm_id --nic $nic_info $name
                  
    done < ./${tenant_id}/instances_backup 
    echo "restore instances success"
}

main()
{
    #1.restore flavor 
    restore_flavor
    
    #2.restore network
    restore_network
    
    #3.restore instances
    restore_instances
    
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

result=$(keystone tenant-create --name $tenant > /dev/null 2>&1)

while read line
do
    id=$(echo $line | awk -F '|' '{print $2}' | tr -d " ")
    name=$(echo $line | awk -F '|' '{print $3}' | tr -d " ")
    if [ "$name" = "$tenant" ];then
        tenant_id=$id
        break
    fi
done < tenant_backup

if [ ! -e  ./${tenant_id} ]; then
  echo "the tenant:${tenant_id} backup information does not exist!"
  exit 1
fi
main
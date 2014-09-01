#!/bin/sh

################################################################################################
## author : zengguoshi
## date : 2014-08-08
## description : A shell to clean the token which expires 7 days ago.
##
## comment:
##     1 this script is recommmend to deploy as a cronjob
##     2 it is hard to judge if the mysqk will do a heavy task in the next moment.so it is resonable to 
##       seperate token flush into lots of tasks.
##       assume it will generate 34w token per day,then if we want to delete in one hour ,then we need delete 6000 records/per second;
##       it is a little one,but is a good choose if we delete once per minute.and if we meet the peak of the mysql busy rate,just 
##       do the job at next minute.
## 
################################################################################################

############################# configurations ###################################################

# Database connection Info 
DB_UserName=root
DB_Password=*****
DB_SchemaName=keystone
DB_Host=localhost

# the expire time
CleanTokenDaysBefore=2  # clean the tokens where expires earlier than CleanTokenMinutes

# if the cpu idle rate lower than that value ,omit the clean task and log the omit behavior to the log file
TotalCPU_MIN_IdleRate=50 
MysqlCPU_MAX_BusyRate=30

# these two parms determin the whole token flush duration.
# a combination with [60,24] imply that it will flush the tokens generating in 24 minutes records in per 60 seconds.
# sleepPerTimeInterval=60 #seconds
sleepPerTimeInterval=60 ## for production
# sleepPerTimeInterval=2 ## for test 

deletePerTimeInterval=24 # minute 
maxDurationTimes=100 # this param just like a watch dog
maxDelayTimes=5 # if it always delay ,then it imply that there has a busy task in mysql,then the token flush should dealy more time.

# log file 
CleanLogPath='/var/log/keystone/'
CleanLogFile="${CleanLogPath}cleanToken.log"

if [ ! -d "$CleanLogPath" ];then 
	mkdir "${CleanLogPath}"
fi

if [ ! -f "$CleanLogFile" ];then 
	touch "$CleanLogFile"
fi

############################start clean task#################################################### 

# calculate the cpu idle rate to choice if we need to do the clean job

echo `date`,'--- start clean ---' >> $CleanLogFile

## start at tht bottom of records which need to flush
# deleteEnd_Time=`date "+%Y-%m-%dT%H:%M:%SZ" -d "-${CleanTokenDaysBefore} days" --utc`
deleteEnd_Time=`date "+%s" -d "-${CleanTokenDaysBefore} days" --utc`
timeInterval=$((-24*60*60))
deleteStart_Time=$(($deleteEnd_Time + $timeInterval))
timeInterval=$(($deletePerTimeInterval*60))

# echo 'deleteStart_Time:' $deleteStart_Time
# echo 'deleteEnd_Time:' $deleteEnd_Time
# echo 'timeInterval:' $timeInterval
cnt=0
cur_delayTimes=0

while [ $cnt -lt $maxDurationTimes ]
do
    cur_CpuIdleRate=`top -n 1 | awk 'NR==3' | awk -F [:,%] '{print $8}' | awk '{printf("%d", $2)}'`
    cur_MysqlCurBusyRate=`top -n 1 | grep mysql | awk '{printf("%d", $10)}'`
     
    echo 'del',$cur_MysqlCurBusyRate,'del'
    if [ "$cur_MysqlCurBusyRate" = "" ];then
        cur_MysqlCurBusyRate=0
    fi

    # echo 'cur_CpuIdleRate:',$cur_CpuIdleRate
    # echo 'cur_MysqlCurBusyRate:',$cur_MysqlCurBusyRate
           
    if [[ $cur_MysqlCurBusyRate -lt $MysqlCPU_MAX_BusyRate ]] && [[ $cur_CpuIdleRate -gt $TotalCPU_MIN_IdleRate ]];then
        
        deleteStart_Time=$(($deleteStart_Time + $timeInterval))
	# calculate the expires point
	# as the token use utc as expires time,here we also use utc.
	expiresTime=$(date "+%Y-%m-%dT%H:%M:%SZ" -d "1970-01-01 $deleteStart_Time seconds")
        
        # echo $expiresTime
        # cnt=`mysql -u $DB_UserName --password=${DB_Password} -e "select count(*) as cnt from ${DB_SchemaName}.token where expires < '${expiresTime}';" | awk -F "cnt"  '{printf("%d",$1)}'`
        # echo 'before delete, cnt' $cnt
	
        mysql -u $DB_UserName --password=${DB_Password} -e "delete from ${DB_SchemaName}.token where expires < '${expiresTime}';"  #>> ${CleanLogFile} 2>&1
        
        # cnt=`mysql -u $DB_UserName --password=${DB_Password} -e "select count(*) as cnt from ${DB_SchemaName}.token where expires < '${expiresTime}';" | awk -F "cnt"  '{printf("%d",$1)}'`
        # echo 'after delete,cnt' $cnt
    else
        ((cur_delayTimes++))
    fi
    
    if [ $deleteStart_Time -lt $deleteEnd_Time ];then
        if [ $cur_delayTimes -lt $maxDelayTimes ];then
            sleep  $sleepPerTimeInterval
        else
            sleep $(($sleepPerTimeInterval*5))
            cur_delayTimes=0
        fi
    else
        break
    fi
done
    
echo -e `date`,'---- finished ----\n\n' >> $CleanLogFile

#!/bin/bash

# 监控jar服务，若宕机则重启
function monitorJarService
{
    JAR_NAME=$1  # jar名称
    JAR_PATH=$2  # jar路径
    LOG_HOME=$3  # 日志路径
    PROFECT_NAME=$4  # jar服务别名，用于日记记录

    PROCESS_NUM=`ps -ef | grep "$1" | grep -v "grep" | wc -l`
    if [ $PROCESS_NUM -ge 1 ];
    then
        echo "时间是：`date '+%Y%m%d %H:%M:%S'` $PROFECT_NAME  正常运行" >> $LOG_HOME/monitor.jarService.log
    else
        echo "时间是：`date '+%Y%m%d %H:%M:%S'` $PROFECT_NAME  异常，尝试重启。" >> $LOG_HOME/monitor.jarService.log
        nohup java -jar $JAR_PATH/$JAR_NAME  > /dev/null 2>&1 &
    fi
}

while : do 
   # tomcat路径   监听url   日志路径   tomcat别名，用于日志记录
   monitorJarService 'Socket.jar' '/home' './' '毕节'

   sleep 5
   monitorJarService 'socketTG.jar' '/home' './' '潼关'

   sleep 5
   monitorJarService 'Socket2.jar' '/usr/local/java' './' '交城'
   
   # 5分钟监控间隔时间
   sleep 300
done
#!/bin/bash

# 监听tomcat服务
function monitorTomcat 
{
   TOMCAT_HOME=$1  # tomcat路径
   URL=$2 # 监听url
   LOG_HOME=$3 # 日志路径
   PROFECT_NAME=$4  # tomcat别名，用于日志记录

   SHUTDOWN='$TOMCAT_HOME/bin/shutdown.sh'
   STARTTOMCAT='$TOMCAT_HOME/bin/startup.sh'
   CODE=`curl -I -m 30 -o /dev/null -s -w %{http_code}"\n" $URL`


   echo "访问时间是：`date '+%Y%m%d %H:%M:%S'`--$CODE--->$URL" >>  $LOG_HOME/monitor.tomcat.visit.log  

   if [  $CODE  -eq  200 ];then

      echo "$PROFECT_NAME -- Tomcat运行正常,时间为:`date '+%Y%m%d %H:%M:%S'`"  >>  $LOG_HOME/monitor.tomcat.visit.log  

   else
      echo "第二次判断 -- $PROFECT_NAME" >>  $LOG_HOME/monitor.tomcat.visit.log  
      if [  $CODE  -eq  200 ];then
         echo "$PROFECT_NAME -- Tomcat运行正常,时间为:`date '+%Y%m%d %H:%M:%S'`" >>  $LOG_HOME/monitor.tomcat.visit.log  
      else
         echo "尝试重新启动，时间为:`date '+%Y%m%d %H:%M:%S'`" >>  $LOG_HOME/monitor.tomcat.visit.log  

         ps -ef|grep tomcat |awk  'NR==1{ print $2}' | xargs kill -9
         cd $TOMCAT_HOME/bin/
         bash startup.sh &
      fi
   fi 
}

while true; do 
   # tomcat路径   监听url   日志路径   tomcat别名，用于日志记录
   monitorTomcat '/usr/local/tomcat/apache-tomcat-8.5.20' 'http://127.0.0.1:40000/' './' '项目一'

   sleep 5
   monitorTomcat '/usr/local/tomcat3/apache-tomcat-8.5.20' 'http://127.0.0.1:28880/' './' '项目二'

   sleep 5
   monitorTomcat '/usr/local/tomcat2' 'http://127.0.0.1:50001/' './' '项目三'
   
   # 5分钟监控间隔时间
   sleep 300
done
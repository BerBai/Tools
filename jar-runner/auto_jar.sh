#!/bin/bash
# chkconfig: 2345 85 15
# description:auto_run


#-----------使用说明-----------#
#Author: bai5775@outlook.com
#v1 2021.07.04
#1.APP_HOME修改为jar包路径
#2.！！！ jar包目录中只能存在一个jar包 ！！！


APP_HOME=/work/project
DATE=`date +%Y%m%d%H%M`
JAR_HOME_TOW="`cd ${APP_HOME} && find *.jar `"
APP_NAME=${JAR_HOME_TOW}

cd $APP_HOME

is_file_exist(){
  count="`find $APP_HOME/*.jar -type f -print | wc -l`"
  if [ $count = 1 ];then
    return 0
  else
    return 1
  fi
}

is_exist(){
  pid=`ps -ef|grep $APP_NAME|grep -v grep|awk '{print $2}' `   
  if [ -z "${pid}" ]; then
    return 1
  else
    return 0
  fi
}

start(){
  is_exist
  if [ $? -eq "0" ]; then
    echo "warn: $APP_NAME is already running. (pid=$pid)"
  else
    nohup java -jar $APP_NAME  > /dev/null 2>&1 &
    echo "${APP_NAME} start success"
  fi
}

echo "================================================="
is_file_exist
if [ $? = 0 ];then
  start
else
  echo "Number of files exceeded, not run this script"
fi
echo "================================================="
#!/bin/bash
# chkconfig: 2345 85 15
# description:auto_run

#-----------使用说明-----------#
#Author: bai5775@outlook.com
#v1 2021.07.04
#1.APP_HOME修改为jar包路径
#2.！！！ jar包目录中只能存在一个jar包 ！！！
#3.备份路径在backup，会自动创建
#4.Tips: start|stop|restart|status|backup


APP_HOME=/work/project
DATE=`date +%Y%m%d%H%M`
JAR_HOME_TOW="`cd ${APP_HOME} && find *.jar `"
APP_NAME=${JAR_HOME_TOW}

cd $APP_HOME

# 检查*.jar是否存在
is_file_exist(){
  count="`find $APP_HOME/*.jar -type f -print | wc -l`"
  if [ $count = 1 ];then
    return 0
  else
    return 1
  fi
}

# 备份jar包
backup(){
  if [ -d "$APP_HOME/backup" ];then
    echo "backup folder exist, continue to backup jar-file"
  else
    echo "backup folder is't exist, crate backup folder"
    mkdir -p $APP_HOME/backup
  fi
  echo "success：backup $APP_NAME to $APP_HOME/backup"
  mv $APP_NAME $APP_NAME-$DATE
  mv $APP_NAME-$DATE $APP_HOME/backup
}

#检查程序是否在运行
is_exist(){
  pid=`ps -ef|grep $APP_NAME|grep -v grep|awk '{print $2}' `
  #如果不存在返回1，存在返回0     
  if [ -z "${pid}" ]; then
    return 1
  else
    return 0
  fi
}
 
#启动方法
start(){
  is_exist
  if [ $? -eq "0" ]; then
    echo "warn: $APP_NAME is already running. (pid=$pid)"
  else
    nohup java -jar $APP_NAME  > /dev/null 2>&1 &
    echo "${APP_NAME} start success"
  fi
}
 
#停止方法
stop(){
  is_exist
  if [ $? -eq "0" ]; then
    kill -9 $pid
	echo "${APP_NAME} stop success"
  else
    echo "warn: $APP_NAME is not running"
  fi  
}
 
#输出运行状态
status(){
  is_exist
  if [ $? -eq "0" ]; then
    echo "warn: $APP_NAME is already running. (pid=$pid)"
  else
    echo "warn: $APP_NAME is not running"
  fi
}

echo "================================================="
is_file_exist
if [ $? = 0 ];then
  #根据输入参数，选择执行对应方法，不输入则执行使用说明
  case "$1" in
    "start")
      start
      ;;
    "stop")
      stop
      ;;
    "status")
      status
      ;;
    "restart")
      stop
      echo "restart the application ..."
      start
      ;;
    "backup")
      backup
      ;;
    *)
      echo "Tips: start|stop|restart|status|backup"
      ;;
  esac
else
  echo "Number of files exceeded, not run this script"
fi
echo "================================================="
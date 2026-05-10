#!/bin/sh

# tomcat启动程序(这里注意tomcat实际安装的路径)
StartTomcat=/data/service/tomcat8.5.69/bin/startup.sh
TomcatCache=/data/shell/tomcat/cache

#定义要监控的页面地址
TomcatUrl=http://localhost:8080

#日志输出
GetPageInfo=/data/shell/tomcat/info/Monitor.Info
MonitorLog=/data/shell/tomcat/log/Monitor.log

# 获取tomcat进程ID（其中[grep -w 'tomcat']代码中的tomcat需要替换为你的tomcat文件夹名）
TomcatID=$(ps -ef |grep tomcat |grep -w 'tomcat8.5.69'|grep -v 'grep'|awk '{print $2}')
# 检测是否启动成功(成功的话页面会返回状态"200")
TomcatServiceCode=$(curl -s -o $GetPageInfo -m 10 --connect-timeout 10 $TomcatUrl -w %{http_code})

Monitor()
{
	echo "[info][$(date +'%F %H:%M:%S')]开始监控..."
	echo "---------------------------------------------------------------------------------------------------------"
	TomcatMonitor
	echo "---------------------------------------------------------------------------------------------------------"
}

TomcatMonitor()
{
	if [ $TomcatID ];then #这里判断Tomcat进程是否存在
		echo "[info][$(date +'%F %H:%M:%S')]Tomcat端启动成功！当前tomcat进程ID为:$TomcatID"
		 echo "[info][$(date +'%F %H:%M:%S')]当前Tomcat进程ID为:$TomcatID,继续检测页面..."
		 if [ $TomcatServiceCode -eq 200 ];then
		 	echo "[info][$(date +'%F %H:%M:%S')]页面返回码为$TomcatServiceCode，tomcat启动成功，测试页面正常"
		 else
		 	echo "[error][$(date +'%F %H:%M:%S')]tomcat页面出错，请注意...状态码为$TomcatServiceCode，错误日志已输出到$GetPageInfo"
		 	echo "[error][$(date +'%F %H:%M:%S')]页面访问出错，开始重启tomcat"
		 	kill -9 $TomcatID # 杀掉原tomcat进程
		 	sleep 3
		 	rm -rf $TomcatCache # 清理tomcat缓存
		 	$StartTomcat
		 fi
	else
		echo "[error][$(date +'%F %H:%M:%S')]Tomcat进程不存在!Tomcat开始自动重启..."
		echo "[info][$(date +'%F %H:%M:%S')]正在重启Tomcat,$StartTomcat，请稍候..."
		rm -rf $TomcatCache
		$StartTomcat
	fi
	echo "*********************************************************"
}


while true;do
    Monitor>>$MonitorLog
    sleep 60
done




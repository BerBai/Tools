#!/bin/bash
# chkconfig: 2345 55 25
# description: mongodb

### BEGIN INIT INFO
# Provides:          mongodb
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts mongodb
# Description:       starts the mongodb
### END INIT INFO

# 指定MongdoDB的根目录，需自行修改
MONGO_PATH=/www/server/mongodb
if [ ! -f $MONGO_PATH/bin/mongod ];then
	echo "No installation of mognodb."
	exit;
fi

# 指定MongdoDB的配置文件，需自行修改
Config=/www/server/mongodb/config.conf
# # 从Shell文件名获取MongoDB端口号
# mongodbPort=`echo $0 | awk -F '_' '{print $2 }' `
# if [ "$mongodbPort" != "" ];then
# 	Config="/www/server/mongodb/config.${mongodbPort}.conf"
# fi
echo "当前MongoDB配置文件: ${Config}"


# 执行用户
 User=root


# 启动数据库
start()
{
	#chmod -R mongo:mongo /www/server/mongodb
	sudo -u $User mongod -f $Config
}

# 停止数据库
stop()
{
	sudo -u $User mongod --shutdown -f $Config
	a=`ps aux|grep '/www/server/mongodb'|grep -v 'grep'| grep $Config  |awk '{print $2}'`
        if [ "$a" != "" ];then
            kill -9 $a
        fi
        echo '关闭MongoDB数据库成功'
}

# 数据库状态
status()
{
        a=`ps aux|grep '/www/server/mongodb'|grep -v 'grep'| grep $Config  |awk '{print $2}'`
        if [ "$a" != "" ];then
            echo "当前MongoDB已启动, 进程号为: $a"
        else 
            echo "当前MongoDB未启动"
        fi
}

# 修复数据库
repair()
{
        a=`ps aux|grep '/www/server/mongodb'|grep -v 'grep'| grep $Config  |awk '{print $2}'`
        if [ "$a" != "" ];then
            echo "当前MongoDB已启动, 请停止后在进行修复数据"
        else 
           dbPathNum=`grep 'dbPath' $Config  | grep -v '#'  | wc -l`  
           if [ "$dbPathNum" -gt 1 ];then
           	echo '当前MongoDB配置文件错误: 含有多个dbPath配置, 请检查'
           else
		dbPath=`grep 'dbPath' $Config  | grep -v '#'  |  awk '{print $2}' `
                echo "是否确定在${dbPath}数据库目录下进行修复数据？ 修复涉及删除文件, 请仔细检查【确定按y、取消修复按n】 "
	        read ensureDbPath
                if [ $(echo $ensureDbPath | tr [a-z] [A-Z]) == "Y" ];then
	                if [ -d $dbPath ];then
				             echo "当前MongoDB数据库目录: $dbPath"
                	        rm -rf ${dbPath}/mongod.lock
                       		mongod --dbpath $dbPath --repair
                       		sleep 5s
	                        rm -rf $dbPath/storage.bson
	                        echo "当前MongoDB数据库修复完成, 尝试启动看能否成功"
			else
				echo "当前MongoDB数据库文件目录不存在: [${dbPath}]请检查"
			fi
		else
			echo '取消当前MongoDB数据库修复'
		fi
           fi
        fi
 
}



case "$1" in
        'start')
                start
                ;;
        'stop')
                stop
                ;;
        'restart')
        	stop
		sleep 2
                start
                ;;
        'status')
                status
                ;;
        'repair')
                repair
                ;;
        *)
                echo "Usage: /etc/init.d/mongodb {start|stop|restart|status|repair}"
        ;;
esac


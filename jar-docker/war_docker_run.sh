#!/bin/bash

#-----------使用说明-----------#
#Author: bai5775@outlook.com
#v1 2021.04.28
#1.备份war包
#2.停止、删除docker容器
#3.删除旧docker镜像
#4.创建Dockerfile文件
#5.构建新docker镜像
#6.运行docker容器

# 操作/项目路径(Dockerfile存放的路径)
BASE_PATH=/work/project
# 源war路径  
SOURCE_PATH=/mydata/jenkins_home/workspace/tomcat-demo/target  
# 打包后war名字
SERVER_NAME=sprintboot_tomcat_demo-0.0.1-SNAPSHOT
# docker 镜像/容器名字
DOCKER_NAME=demo
# 获取容器id
CID=$(docker ps | grep "$DOCKER_NAME" | awk '{print $1}')
# 获取镜像id
IID=$(docker images | grep "$DOCKER_NAME" | awk '{print $3}')
# 获取时间
DATE=`date +%Y%m%d%H%M`
# 镜像构建作者标识
AUTHOR=bai5775@outlook.com
 
# 创建构建docker镜像文件
function createDockerfile() {
    echo "检测docker构建文件 $BASE_PATH/$DOCKER_NAME/Dockerfile 是否存在"
    if [ ! -f "$BASE_PATH/$DOCKER_NAME/Dockerfile" ]; then
        echo "from tomcat
MAINTAINER $AUTHOR
RUN rm -rf /usr/local/tomcat/webapps/*
COPY $DOCKER_NAME.war   /usr/local/tomcat/webapps
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone" > $BASE_PATH/$DOCKER_NAME/Dockerfile
        echo "创建构建文件 $BASE_PATH/$DOCKER_NAME/Dockerfile 成功，内容为"
        cat $BASE_PATH/$DOCKER_NAME/Dockerfile
    else 
        echo "构建文件 $BASE_PATH/$DOCKER_NAME/Dockerfile 存在"
    fi
}

# 将最新的war包移动到项目环境
function transfer(){
    echo "检测项目文件夹$BASE_PATH/$DOCKER_NAME是否存在"
	if [ ! -d "$BASE_PATH/$DOCKER_NAME" ]; then
      	mkdir -p $BASE_PATH/$DOCKER_NAME
        echo "$BASE_PATH/$DOCKER_NAME文件夹创建完成"
    else
      	echo "$BASE_PATH/$DOCKER_NAME文件夹已经存在"
    fi

    echo "最新的war包 $SOURCE_PATH/$SERVER_NAME.war 迁移至项目路径 $BASE_PATH/$DOCKER_NAME ...."
    cp $SOURCE_PATH/$SERVER_NAME.war $BASE_PATH/$DOCKER_NAME
    mv $BASE_PATH/$DOCKER_NAME/$SERVER_NAME.war $BASE_PATH/$DOCKER_NAME/$DOCKER_NAME.war 
    echo "迁移完成"
}
 
# 备份原先的war包
function backup(){
	echo "检测项目文件夹$BASE_PATH/backup/$DOCKER_NAME是否存在"
	if [ ! -d "$BASE_PATH/backup/$DOCKER_NAME" ];then
      	mkdir -p $BASE_PATH/backup/$DOCKER_NAME
        echo "$BASE_PATH/backup/$DOCKER_NAME文件夹创建完成"
    else
      	echo "$BASE_PATH/backup/$DOCKER_NAME文件夹已经存在"
    fi
    
	if [ -f "$BASE_PATH/$DOCKER_NAME.war" ]; then
    	echo "$DOCKER_NAME.war 备份..."
        mv $BASE_PATH/$DOCKER_NAME.war $BASE_PATH/$DOCKER_NAME-$DATE.war
        mv $BASE_PATH/$DOCKER_NAME-$DATE.war $BASE_PATH/backup/$DOCKER_NAME
        echo "备份 $DOCKER_NAME.war 完成"
    else
    	echo "$BASE_PATH/$DOCKER_NAME.war不存在，跳过备份"
    fi
}
 
# 构建docker镜像
function build(){
	if [ -n "$IID" ]; then
		echo "存在$DOCKER_NAME镜像，IID=$IID"
        if [ -n "$CID" ]; then
			echo "存在正在运行的$DOCKER_NAME容器，CID=$CID"
	        docker stop $DOCKER_NAME
            docker rm $DOCKER_NAME
			echo "停止并删除$DOCKER_NAME容器，CID=$CID"
    	fi
	    docker rmi $DOCKER_NAME
        echo "删除docker $DOCKER_NAME镜像"
	fi
	
	cd $BASE_PATH/$DOCKER_NAME
	echo "进入$BASE_PATH/$DOCKER_NAME目录，开始构建镜像"
	docker build -t $DOCKER_NAME .
	echo "构建镜像完成"
}
 
# 运行docker容器
function run(){
	docker run --name $DOCKER_NAME -d -p 8082:8080 $DOCKER_NAME
	echo "$DOCKER_NAME容器 运行完成"
	echo "检测运行情况"
	CID=$(docker ps | grep "$DOCKER_NAME" | awk '{print $1}')
	if [ -n "$CID" ]; then
		echo "容器$DOCKER_NAME 运行成功"
	else
		echo "容器$DOCKER_NAME 运行失败"
	fi
}

function main(){
	backup
	transfer
    createDockerfile
	build
    run
}
 
# 入口
main
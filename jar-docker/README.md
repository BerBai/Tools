# jar-docker

> vendored from [BerBai/recode](https://github.com/BerBai/recode) @ 2f6f57f

把 Java 制品（jar / war）一键自动化打成 Docker 镜像并运行的部署脚本。典型用在 Jenkins 流水线 "构建产物 → 拷贝到部署机 → 触发本脚本" 这一步。

| 脚本 | 基镜像 | 端口映射 | 用途 |
|------|--------|---------|------|
| `jar_docker_run.sh` | `java:8` | `8080:8080` | jar 包 → 镜像 → 容器 |
| `war_docker_run.sh` | `tomcat`  | `8082:8080` | war 包 → tomcat 镜像 → 容器 |

两个脚本流程完全一样，只是基镜像和制品类型不同：

1. **backup**：把上一版制品 `mv` 到 `$BASE_PATH/backup/$DOCKER_NAME/`，文件名追加时间戳
2. **transfer**：把最新制品从 `$SOURCE_PATH/$SERVER_NAME.{jar,war}` 拷到 `$BASE_PATH/$DOCKER_NAME/` 并改名为 `$DOCKER_NAME.{jar,war}`
3. **createDockerfile**：如果 `$BASE_PATH/$DOCKER_NAME/Dockerfile` 不存在就生成一份（带 `Asia/Shanghai` 时区）
4. **build**：停掉旧容器、删掉旧镜像，`docker build -t $DOCKER_NAME .`
5. **run**：`docker run --name $DOCKER_NAME -d -p ... $DOCKER_NAME`

## 使用前必改

每个脚本顶部 4 个硬编码变量都要按实际环境改：

```bash
BASE_PATH=/work/project                                          # 部署目录（Dockerfile 落地处）
SOURCE_PATH=/mydata/jenkins_home/workspace/jar-docker-demo/target # 制品产出目录（Jenkins workspace 之类）
SERVER_NAME=demo-0.0.1-SNAPSHOT                                   # mvn package 出来的 jar/war 名字（不含后缀）
DOCKER_NAME=demo                                                  # 镜像 + 容器名（也是部署子目录名）
```

`AUTHOR=bai5775@outlook.com` 是 Dockerfile 里的 `MAINTAINER` 标签，无关紧要可以保留。

## 用法

```bash
# 在部署机上（jar/war 已通过 Jenkins/scp 推到 $SOURCE_PATH）
./jar_docker_run.sh
# 或
./war_docker_run.sh
```

跑完后访问 `http://<host>:8080`（jar）或 `http://<host>:8082`（war）。

## 注意事项

- 脚本不接受任何参数，**全靠改头部变量**驱动。一台机器跑多个服务 → 拷脚本改 `DOCKER_NAME` 和端口。
- `run()` 函数里的端口映射是写死的（`-p 8080:8080` / `-p 8082:8080`），改端口要改 `run()` 函数本身。
- 自动生成的 `Dockerfile` 只有时区配置，**不挂日志卷、不挂配置卷、不带 healthcheck**，复杂场景请手动放一份 `$BASE_PATH/$DOCKER_NAME/Dockerfile`，脚本检测到存在就跳过生成。
- jar 模式的 `Dockerfile` 用 `from java:8`（**Docker Hub 上 `java` 镜像已废弃**，长期跑建议手写 Dockerfile 改成 `openjdk:8` / `eclipse-temurin:8` 等）。
- 脚本里的路径硬编码 **本仓库不修改**（原样 vendor），需要改请回上游 [BerBai/recode](https://github.com/BerBai/recode) 提 PR。

## 依赖

| 工具 | 用途 |
|------|------|
| `bash` | 运行脚本 |
| `docker` | 构建/运行镜像（目标服务器需要，本地无需安装） |

## 来源

vendor 自 [BerBai/recode](https://github.com/BerBai/recode) 仓库的 `java/jar_docker_run.sh` 和 `java/war_docker_run.sh`，详见 `UPSTREAM.md`。

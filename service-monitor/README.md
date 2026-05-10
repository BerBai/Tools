# service-monitor

> vendored from [BerBai/recode](https://github.com/BerBai/recode) @ 2f6f57f

服务存活监控 + 自愈脚本集合。三个脚本都是 `while true; do ... ; sleep N; done` 形式的守护进程，建议用 `nohup ./xxx.sh > /var/log/xxx.log 2>&1 &` 跑后台，或者用 systemd unit 包装。

| 脚本 | 监控对象 | 检测方式 | 自愈动作 |
|------|---------|---------|---------|
| `tomcat_single.sh` | 单个 tomcat | 进程 + 页面 HTTP 200 双重检测 | `kill -9` + 清缓存 + 重启 |
| `tomcat_multi.sh`  | 多个 tomcat | 轮询每个 URL 的 HTTP 200 | `kill -9` 后 `bash startup.sh &` |
| `jar_multi.sh`     | 多个 jar 进程 | `ps -ef \| grep <jar>` 计数 | `nohup java -jar` 拉起 |

## 使用前必改

**所有路径 / URL / 进程名都是写死的示例**，使用前必须改函数里 / 函数调用里的参数。

### `tomcat_single.sh`

顶部硬编码变量全部要改：

```bash
StartTomcat=/data/service/tomcat8.5.69/bin/startup.sh   # tomcat startup 脚本绝对路径
TomcatCache=/data/shell/tomcat/cache                    # tomcat work/缓存目录（重启前清掉）
TomcatUrl=http://localhost:8080                         # 健康检查 URL
GetPageInfo=/data/shell/tomcat/info/Monitor.Info        # 页面响应内容落盘路径
MonitorLog=/data/shell/tomcat/log/Monitor.log           # 监控日志
TomcatID=$(ps -ef | grep tomcat | grep -w 'tomcat8.5.69' | ...)  # ← 'tomcat8.5.69' 改成你 tomcat 文件夹名
```

监控间隔：`sleep 60`（1 分钟）。

### `tomcat_multi.sh` / `jar_multi.sh`

底部 `while true` 循环里有示例 `monitorTomcat`/`monitorJarService` 调用，按你实际项目数量增删 + 改参数：

```bash
# tomcat_multi.sh
monitorTomcat '/usr/local/tomcat/apache-tomcat-8.5.20' 'http://127.0.0.1:40000/' './' '项目一'
#              ^ TOMCAT_HOME                            ^ URL                     ^ LOG_HOME ^ 别名

# jar_multi.sh
monitorJarService 'Socket.jar' '/home' './' '毕节'
#                  ^ JAR_NAME   ^ JAR_PATH ^ LOG_HOME ^ 别名
```

监控间隔：每项之间 `sleep 5`，整轮之间 `sleep 300`（5 分钟）。

## 用法

```bash
# 后台跑（最常见）
nohup ./tomcat_single.sh > /var/log/tomcat-monitor.log 2>&1 &

# 或包成 systemd 服务（推荐，自带 restart on failure）
# /etc/systemd/system/tomcat-monitor.service:
# [Service]
# ExecStart=/path/to/tomcat_single.sh
# Restart=always
# [Install]
# WantedBy=multi-user.target
```

`tomcat_single.sh` 自身会把每轮检测结果 `>> $MonitorLog`；`tomcat_multi.sh` / `jar_multi.sh` 写到 `$LOG_HOME/monitor.tomcat.visit.log` / `$LOG_HOME/monitor.jarService.log`。

## 注意事项

- 三个脚本都是**死循环 + sleep**，不退出。重启策略靠外面的 nohup/systemd 兜底。
- `tomcat_multi.sh` 的 "重启" 用 `ps -ef | grep tomcat | awk 'NR==1{print $2}' | xargs kill -9` —— **会杀掉 ps 拿到的第一个 tomcat 进程**，多个 tomcat 实例混跑时不要直接用，参数化改造请回上游提 PR。
- `jar_multi.sh` 第 21 行原文是 `while : do`（缺 `;`），bash 容忍但 shellcheck 报错；**本仓库不修改**，原样 vendor。
- 自愈用的是粗暴的 `kill -9`，没有优雅停机。
- 脚本里的路径/URL 硬编码 **本仓库不修改**，需要改请回上游 [BerBai/recode](https://github.com/BerBai/recode) 提 PR。

## 依赖

| 工具 | 用途 |
|------|------|
| `bash` | 运行脚本 |
| `curl` | HTTP 健康检查（`tomcat_single.sh` / `tomcat_multi.sh`） |
| 被监控对象本身（tomcat / java） | 自愈时拉起进程（目标服务器需要） |

## 来源

vendor 自 [BerBai/recode](https://github.com/BerBai/recode) 仓库的 `java/Monitor.sh`、`script/tomcat.monitor.sh`、`script/jar.monitor.sh`，详见 `UPSTREAM.md`。

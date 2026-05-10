# jar-runner

> vendored from [BerBai/recode](https://github.com/BerBai/recode) @ 2f6f57f

Linux 上 Java jar 进程的生命周期管理脚本。两个版本：

| 脚本 | 用途 |
|------|------|
| `auto_jar.sh` | **简化版**：开机/手动一键启动，只做 "如果没在跑就 `nohup java -jar` 起来"，适合塞进 `rc.local` / cron `@reboot` |
| `run_jar.sh`  | **完整版**：`start \| stop \| restart \| status \| backup` 全套 init 风格命令 |

两个脚本都自带 `# chkconfig: 2345 85 15` 头，可以丢到 `/etc/init.d/` 跑 `chkconfig --add` 注册成 SysV 服务（CentOS 6 / 老 Linux）。

## 使用前必改

脚本顶部硬编码了 `APP_HOME=/work/project`，**改成你机器上 jar 包所在目录**：

```bash
APP_HOME=/work/project    # ← 改这里
```

> ⚠️ **约束**：`APP_HOME` 目录里**只能放一个 `*.jar` 文件**。脚本通过 `find $APP_HOME/*.jar` 自动取名，多个 jar 会直接拒绝执行（输出 "Number of files exceeded, not run this script"）。

## 用法

### `auto_jar.sh`（一键启动）

```bash
./auto_jar.sh
# 已在跑：warn: xxx.jar is already running. (pid=...)
# 没在跑：xxx.jar start success
```

### `run_jar.sh`（全套命令）

```bash
./run_jar.sh start      # 启动
./run_jar.sh stop       # kill -9 杀进程
./run_jar.sh restart    # 先 stop 再 start
./run_jar.sh status     # 查看运行状态
./run_jar.sh backup     # mv jar 到 $APP_HOME/backup/，文件名追加时间戳
./run_jar.sh            # 不带参数 → 打印 Tips
```

## 注意事项

- `stop` 用 `kill -9`，没有优雅停机（Spring Boot 的 shutdown hook 不会触发）。线上服务对此敏感的话建议在上游改成 `kill -15` + 等待。
- `is_exist` 用 `ps -ef | grep $APP_NAME` 匹配进程，jar 包文件名不要和无关进程重名。
- `backup` 是 `mv` 不是 `cp` —— 备完原 jar 就没了，配合 CI 出新包的场景用。
- 脚本里的路径硬编码、shellcheck 警告等 **本仓库不修改**（原样 vendor），需要改请回上游 [BerBai/recode](https://github.com/BerBai/recode) 提 PR。

## 依赖

| 工具 | 用途 |
|------|------|
| `bash` | 运行脚本 |
| `java` | 跑 jar 包（目标服务器需要，本地无需安装） |

## 来源

vendor 自 [BerBai/recode](https://github.com/BerBai/recode) 仓库的 `java/auto_jar.sh` 和 `java/run_jar.sh`，详见 `UPSTREAM.md`。

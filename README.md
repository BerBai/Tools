# Tools

个人脚本仓库。集中管理跨平台的命令行小工具、安装脚本、本地代理等，配套一份 `Makefile` 作为统一入口。

🌐 **在线展示**：<https://tools.125520.xyz> · 含 [Find who he/she is](https://tools.125520.xyz/weibo-finder/)（微博图片找原作者）等纯前端小工具

---

## 目录结构

```
Tools/
├── Makefile              # 统一入口：make help 查看所有命令
├── README.md             # 本文件
│
├── npm-offline/          # npm 离线打包工具
│   └── npm_offline_install.sh
├── newapi/               # Claude Code 本地代理
│   ├── anyrouter_local_proxy.ts
│   └── README.md
├── claude-notify/        # Claude Code 通知 hook（本地 + Bark 推送）
│   ├── notify.py         # macOS 实现，被 ~/.claude/hooks/notify.py 软链调用
│   ├── notify.ps1        # Windows 实现（PowerShell）
│   └── README.md
│
├── wmk/                  # 图片/PDF 水印（vendored from BerBai/WMK @ 793c54b, GPL-2.0）
│   ├── LICENSE           # GPL v2，原样保留
│   ├── UPSTREAM.md       # vendor 元数据：URL/SHA/copy-date/license
│   ├── marker.py         # 图片水印（Makefile 暴露）
│   ├── pdf_mark.py       # PDF 水印（保留，不暴露 Makefile target）
│   ├── pdfc.py           # PDF 压缩（基于 ghostscript，保留，不暴露）
│   ├── notionnext.py     # 用途未文档化（保留，不暴露）
│   ├── font/             # 默认字体（庞门正道标题体）
│   └── example/          # 示例图片
│
├── jar-runner/           # Linux 上 Java jar 进程生命周期管理（vendored from BerBai/recode @ 2f6f57f）
│   ├── auto_jar.sh       # 简化版：开机/手动一键启动
│   ├── run_jar.sh        # 完整版：start/stop/restart/status/backup
│   ├── README.md
│   └── UPSTREAM.md
│
├── jar-docker/           # jar/war 自动构建 Docker 镜像并部署（vendored from BerBai/recode @ 2f6f57f）
│   ├── jar_docker_run.sh # 基镜像 java:8，端口 8080:8080
│   ├── war_docker_run.sh # 基镜像 tomcat，端口 8082:8080
│   ├── README.md
│   └── UPSTREAM.md
│
├── service-monitor/      # 服务存活监控 + 自愈（vendored from BerBai/recode @ 2f6f57f）
│   ├── tomcat_single.sh  # 单 tomcat：进程 + 页面双重监控，死则重启
│   ├── tomcat_multi.sh   # 多 tomcat URL 轮询监控
│   ├── jar_multi.sh      # 多 jar 进程监控
│   ├── README.md
│   └── UPSTREAM.md
│
├── mongodb-init/         # MongoDB SysV init.d 风格管理脚本（vendored from BerBai/recode @ 2f6f57f）
│   ├── mongodb.sh        # start/stop/restart/status/repair
│   ├── README.md
│   └── UPSTREAM.md
│
├── docs/                 # GitHub Pages 源（→ tools.125520.xyz, just-the-docs Jekyll 主题）
│   ├── _config.yml      # Jekyll + just-the-docs 配置
│   ├── _sass/color_schemes/tools.scss   # 主色覆盖 #ce4040
│   ├── Gemfile          # 本地预览用 (bundle exec jekyll serve)
│   ├── index.md         # 首页
│   ├── claude-notify.md # 由 make sync-docs 从 claude-notify/README.md 同步
│   ├── newapi.md        # 同上
│   ├── npm-offline.md   # 手写 stub，README 落地后由 sync-docs 接管
│   ├── weibo-finder.md  # sidebar 外链项 → /weibo-finder/
│   ├── CNAME            # 自定义域名
│   ├── weibo-finder/    # 微博图片找原作者（纯前端，从老 tools 仓库迁来）
│   └── findWB/          # 老路径兼容（meta refresh → weibo-finder/）
│
├── dist/                 # 脚本产出物（不要手动改，可随时清理）
│   ├── npm-offline-bundle/
│   └── npm-offline-bundle.tar.gz
│
└── .trellis/             # Trellis 任务管理（与脚本无关）
```

约定：
- **所有脚本一律放功能命名的子目录**（kebab-case），不按平台分文件夹。同一功能的多平台实现放在同一目录里（例如 `foo/foo.sh` + `foo/foo.ps1`）。
- **平台支持情况**通过下方"脚本清单"表格的"支持平台"列体现。
- **可执行产物** → 一律放 `dist/`，可随时 `make clean`。
- **纯前端 Web 小工具** → 一律放 `docs/<工具名>/`，会随 GitHub Pages 一起部署到 `tools.125520.xyz`。
- 每个子目录可有自己的 `README.md` 解释细节，顶层 README 只做索引。

---

## 快速开始

```bash
make help          # 查看所有可用命令
make proxy         # 启动 newapi 本地代理（前台）
make npm-bundle    # 制作 npm 离线安装包
make clean         # 清理 dist/
```

---

## 脚本清单

| 脚本 | 路径 | 支持平台 | 用途 | Makefile target | 文档 |
|------|------|------|------|------|------|
| npm 离线打包 | `npm-offline/npm_offline_install.sh` | Linux, macOS | 把 npm 包及其依赖打成 tar.gz，离线机解压即可用 | `make npm-bundle` | [查看](./npm-offline/README.md) |
| anyrouter 本地代理 | `newapi/anyrouter_local_proxy.ts` | Linux, macOS, Windows | 给 Claude Code 等客户端套一层本地代理，转发到上游 | `make proxy` / `make proxy-bg` | [查看](./newapi/README.md) |
| Claude Code 通知 hook | `claude-notify/notify.py` `claude-notify/notify.ps1` | macOS / Windows（本地通知）；任意（仅 mac 版支持 Bark 推送） | 任务完成/需审批时弹本地通知 + 可选 Bark 推送，由 Claude Code hook 自动调用 | —（hook 触发） | [查看](./claude-notify/README.md) |
| WMK 水印工具 | `wmk/marker.py` `wmk/pdf_mark.py` `wmk/pdfc.py` | 任意（Python 3 + Pillow；`pdfc.py` 还需 ghostscript） | 图片/PDF 水印 + PDF 压缩（vendored from [BerBai/WMK](https://github.com/BerBai/WMK) @ 793c54b, GPL-2.0；仅 `marker.py` 暴露 Makefile target，其它脚本可直接 `python3 wmk/<script>.py` 调用） | `make wmk-deps` / `make wmk-mark` | [查看](./wmk/README.md) |
| jar-runner | `jar-runner/auto_jar.sh` `jar-runner/run_jar.sh` | Linux | 服务器侧 Java jar 进程生命周期管理：`auto_jar.sh` 一键启动；`run_jar.sh` 提供 start/stop/restart/status/backup（vendored from [BerBai/recode](https://github.com/BerBai/recode) @ 2f6f57f） | — | [查看](./jar-runner/README.md) |
| jar-docker | `jar-docker/jar_docker_run.sh` `jar-docker/war_docker_run.sh` | Linux | jar/war 一键自动化打 Docker 镜像并运行；jar 用 `java:8` 基镜像、war 用 `tomcat` 基镜像（vendored from [BerBai/recode](https://github.com/BerBai/recode) @ 2f6f57f） | — | [查看](./jar-docker/README.md) |
| service-monitor | `service-monitor/tomcat_single.sh` `service-monitor/tomcat_multi.sh` `service-monitor/jar_multi.sh` | Linux | 服务存活监控 + 自愈：单 tomcat 进程/页面双检、多 tomcat URL 轮询、多 jar 进程监控；均为 `while true` 守护进程（vendored from [BerBai/recode](https://github.com/BerBai/recode) @ 2f6f57f） | — | [查看](./service-monitor/README.md) |
| mongodb-init | `mongodb-init/mongodb.sh` | Linux | MongoDB SysV `init.d` 风格管理脚本，支持 `start\|stop\|restart\|status\|repair`，典型部署到 `/etc/init.d/mongodb`（vendored from [BerBai/recode](https://github.com/BerBai/recode) @ 2f6f57f） | — | [查看](./mongodb-init/README.md) |

> "支持平台"列说明：列出脚本能直接运行的平台。Linux 上的 bash 脚本一般在 macOS 也能跑（注意 macOS 默认 bash 3.x，必要时 `brew install bash`）；Windows 需通过 WSL 运行 bash 脚本。如果同一功能未来加了 PowerShell / .ps1 实现，把对应平台加进来即可。

---

## 详细说明

### 1. npm 离线安装包（`make npm-bundle`）

把指定 npm 包的完整依赖打成 `dist/npm-offline-bundle.tar.gz`，目标机器无需联网即可 `npm install`。

**联网机器（打包）：**
```bash
make npm-bundle PKG="lodash@4"
# 或直接调脚本（更多选项）：
./npm-offline/npm_offline_install.sh lodash@4
```

**离线机器（安装）：**
```bash
tar -xzf npm-offline-bundle.tar.gz
cd npm-offline-bundle
./install.sh              # 交互式安装
./install.sh --install    # 直接本地安装
./install.sh -G           # 全局安装
./install.sh --no-install # 仅启动 verdaccio，不安装
```

产物布局见 `dist/npm-offline-bundle/README.md`。

### 2. anyrouter 本地代理（`make proxy`）

把 Claude Code / 其他客户端的 API 请求重定向到 `http://127.0.0.1:5000`，由本脚本转发到上游 `MODEL_PROXY_UPSTREAM`。

**前台运行：**
```bash
make proxy                                    # 用默认 upstream
make proxy UPSTREAM=https://YOUR_ANYROUTER_UPSTREAM     # 自定义 upstream
make proxy PORT=5001                          # 自定义端口
```

**后台运行（推荐配合 SessionStart hook）：**
```bash
make proxy-bg     # 后台启动，日志写 /tmp/anyrouter-proxy.log
make proxy-stop   # 停止
make proxy-log    # tail 日志
```

详细 hook 配置示例见 `newapi/README.md`。

### 3. Pages 站点（`docs/`，→ <https://tools.125520.xyz>）

GitHub Pages 部署模式："Deploy from a branch" → `main` / `/docs`，主题为 [just-the-docs](https://just-the-docs.com)，无 GitHub Actions workflow（GH Pages 自动跑 Jekyll 构建）。

**改完工具 README 后同步到 Pages**：
```bash
make sync-docs                       # 把各 README.md 同步到 docs/<tool>.md（含 front-matter 注入 + 相对链接重写）
git add docs/ && git commit -m "docs: sync READMEs"
git push                             # GH Pages 自动 build
```

**本地预览**：
```bash
cd docs && bundle install            # 首次：装 github-pages gem
make docs-serve                      # → http://127.0.0.1:4000
```

**改主色 / 改主题**：编辑 `docs/_sass/color_schemes/tools.scss`。

**新工具加进 sidebar**：
- 有 README → 在 `scripts/sync-docs.sh` 末尾加 `sync_one "<tool>" <nav_order> "<desc>"`，跑一次 `make sync-docs`
- 暂无 README → 手写 `docs/<tool>.md`（含 `nav_order` front-matter）占位，README 落地后 sync-docs 自动接管

---

## 新增脚本

加新脚本时按下面顺序走：

1. **建/选目录**：在仓库根下用功能命名（kebab-case）建子目录，例如 `db-backup/`、`log-rotate/`。同一功能的多平台实现放在同一目录里（如 `db-backup/db-backup.sh` 和 `db-backup/db-backup.ps1`）。
2. **加可执行权限**（Unix 脚本）：`chmod +x your-script.sh`
3. **写一行用途注释**：脚本顶部注释里说清楚 "做什么 + 怎么用"，便于 `head -10` 速查
4. **注册到 Makefile**：在 `Makefile` 加一个 target，并在 target 行尾加 `## 描述`（自动出现在 `make help`）
5. **更新本 README 的"脚本清单"表格**，"支持平台"列如实填写
6. **如果有产物** → 写到 `dist/`，并加进 `make clean`
7. **同步到 Pages 站点**：如果工具有 `README.md`，按上面"Pages 站点"段落把它注册进 `scripts/sync-docs.sh` 并跑 `make sync-docs`

> 命名规则：目录名用 `kebab-case`；脚本文件名用 `小写_下划线.sh` 或 `kebab-case.ts/.ps1`；Makefile target 用 `kebab-case`。

---

## 依赖说明

| 工具 | 用于 | 安装 |
|------|------|------|
| `make` | 跑 Makefile | macOS / Linux 自带；Windows 需 `choco install make` 或用 WSL |
| `bash` ≥ 4 | npm-offline 等 bash 脚本 | macOS 默认是 3.x，建议 `brew install bash`；Windows 用 WSL |
| `node` ≥ 14 + `npx` | newapi 代理、npm 离线包 | https://nodejs.org |
| `verdaccio` | npm 离线包（已 bundle，无需单独装） | — |
| `python3` + `Pillow` | wmk 图片水印 | `make wmk-deps`（即 `pip install Pillow`） |
| `ghostscript` | wmk 的 `pdfc.py` PDF 压缩 | macOS: `brew install ghostscript`；Linux: `apt install ghostscript`（仅手动调用 `python3 wmk/pdfc.py` 时需要）|
| `java` | jar-runner / jar-docker 跑 Java 制品 | 目标服务器自备（这些脚本是上传到服务器执行的运维脚本，本地无需安装） |
| `docker` | jar-docker 构建/运行容器 | 目标服务器自备（同上，本地无需安装） |
| `mongod` | mongodb-init 管理 MongoDB | 目标服务器自备（同上，本地无需安装） |

---

## 许可 & 维护

个人工具集，按需迭代。每个子目录如有特殊说明会单独放 README。

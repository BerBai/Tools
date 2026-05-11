---
title: Home
nav_order: 0
description: 个人脚本与小工具集
permalink: /
---

# Tools
{: .fs-9 }

个人脚本与小工具集。每个工具都是独立的、可单独使用的小脚本。
{: .fs-6 .fw-300 }

[查看 GitHub 仓库](https://github.com/BerBai/Tools){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[立即使用 weibo-finder](/weibo-finder/){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 }

---

## 脚本

- [**claude-notify**](claude-notify) — Claude Code 任务完成 / 需审批通知 hook，本地 toast + 可选 Bark 推送。`macOS · Windows`
- [**newapi**](newapi) — anyrouter 本地代理，把客户端 API 请求转发到指定上游，便于 hook 与多模型切换。`macOS · Linux · Windows`
- [**npm-offline**](npm-offline) — 把任意 npm 包及其完整依赖打成 tar.gz，离线机解压即可 npm install。`macOS · Linux`
- [**wmk**](wmk) — 图片 / PDF 水印工具，`marker.py` 主入口，默认字体已自带。vendored from BerBai/WMK (GPL-2.0)。`macOS · Linux · Windows`
- [**jar-runner**](jar-runner) — Linux 上 Java jar 进程生命周期管理脚本，start / stop / restart / status / backup 全套 + 自带 `chkconfig` 头。`Linux`
- [**jar-docker**](jar-docker) — jar / war 一键打 Docker 镜像并运行，典型用于 Jenkins 构建产物 → 部署机 → 自动起容器。`Linux`
- [**mongodb-init**](mongodb-init) — MongoDB SysV `init.d` 风格管理脚本，可注册成系统服务（`chkconfig` / `update-rc.d`）。`Linux`
- [**service-monitor**](service-monitor) — 服务存活监控 + 自愈守护脚本集，覆盖单/多 tomcat 与多 jar 进程。`Linux`

## Web 工具

- [**Find who he/she is**](/weibo-finder/) — 给一张微博图片链接，反查出原作者主页。从老 tools 仓库迁来的小工具。`浏览器 · 无需后端`

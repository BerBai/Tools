# claude-notify

Claude Code 通知 hook —— 在任务完成 / 需审批时弹本地通知，可选推送到 [Bark](https://day.app)，macOS + Windows 双平台覆盖。

## Why

**问题**：Claude Code 长任务（几十秒~数分钟级）跑完没声音，开新窗口干别的就漏了；交互式 `Notification` 事件（需要批准命令、需要补输入）卡在那等用户但前台没切回去也注意不到。

**思路**：注册两个 hook（`Stop` / `Notification`），由 Claude Code 在事件触发时通过 stdin 喂 JSON 给本脚本，本脚本：

1. 读 stdin JSON 拿 `cwd` / `transcript_path` / `message`
2. 从 transcript 文件里抽最后一条 assistant 文本作为通知正文（`Stop` 事件用）
3. 调系统原生通知 API 弹 toast
4. 可选：同样的标题正文 POST 到 Bark，手机收推送

**对比同类**：

| 方案 | 跨平台 | 拿得到 transcript 内容 | 手机推送 |
|------|------|------|------|
| Claude Code 自带响铃 | ✅ | ❌（仅响） | ❌ |
| 写 hook 调 `osascript` 一行 | macOS 限定 | ❌ | ❌ |
| **本工具** | macOS + Windows | ✅（解析 JSONL transcript） | ✅（macOS 端集成 Bark） |

同一份脚本两份实现按平台选用：

| 文件 | 适用平台 | 本地通知后端 | Bark 推送 |
|------|----------|-------------|-----------|
| `notify.py`  | macOS（也可 Linux/WSL，本地通知部分会降级失败但不报错） | `terminal-notifier` → `osascript` | ✅ |
| `notify.ps1` | Windows | BurntToast → WinRT Toast → Balloon | ❌ |

两份脚本共享同一份 stdin JSON 协议（`cwd` / `transcript_path` / `message`）和事件参数（`Stop` / `Notification`），所以 hook 配置只是命令不同。

## 快速上手

**macOS**：

```bash
# 1. （可选）装 terminal-notifier 让通知更好看（不装会自动 fallback osascript）
brew install terminal-notifier

# 2. 软链到 ~/.claude/hooks/
mkdir -p ~/.claude/hooks
ln -s "$PWD/claude-notify/notify.py" ~/.claude/hooks/notify.py

# 3. 编辑 ~/.claude/settings.json，加 Stop / Notification hook（见"详细用法"）

# 4. 手测
echo '{"cwd":"/tmp/demo"}' | ./claude-notify/notify.py Stop
```

**Windows**：

```powershell
# 1. （推荐）装 BurntToast 让通知最好看
Install-Module BurntToast -Scope CurrentUser

# 2. 编辑 %USERPROFILE%\.claude\settings.json 加 hook（见"详细用法"），命令直接指向项目路径

# 3. 手测
'{"cwd":"C:/tmp/demo"}' | pwsh -File .\claude-notify\notify.ps1 -Event Stop
```

## 安装

**通用依赖**：
- Claude Code（已安装且写过 `~/.claude/settings.json`）

**macOS（`notify.py`）**：
- `python3` ≥ 3.8（`from __future__ import annotations` 即可，无第三方包依赖；用 `urllib.request` 调 Bark）
- 可选：`terminal-notifier`（`brew install terminal-notifier`），不装则 fallback `osascript`
- macOS 系统设置 → 通知 → 允许 `Script Editor` / `terminal-notifier` 弹通知（首次会弹权限框）

**Windows（`notify.ps1`）**：
- PowerShell 5.1+（系统自带）或 PowerShell 7（`pwsh`）
- 可选：`BurntToast` 模块（`Install-Module BurntToast -Scope CurrentUser`），不装则 fallback WinRT Toast → Balloon
- Windows 10+（WinRT 后端要求）

**Bark（仅 macOS 端集成）**：
- iOS 上装 [Bark](https://apps.apple.com/cn/app/bark-customed-notifications/id1403753865)
- 拿到自己的 device key（App 里"查看 key"）
- 设环境变量 `BARK_KEY=xxxxx`（写在 shell rc 或 `~/.claude/settings.json` 的 `env` 段都行）

## 详细用法

### macOS：notify.py

#### 托管方式

项目内 `claude-notify/notify.py` 是唯一来源，`~/.claude/hooks/notify.py` 是指向本目录的 symlink：

```bash
ls -la ~/.claude/hooks/notify.py
# -> /path/Tools/claude-notify/notify.py
```

修改本文件即立即生效，无需复制或重启 Claude Code。

#### hook 配置

`~/.claude/settings.json`：

```json
{
  "hooks": {
    "Stop": [
      { "matcher": "*", "hooks": [
        { "type": "command", "command": "$HOME/.claude/hooks/notify.py Stop" }
      ]}
    ],
    "Notification": [
      { "matcher": "*", "hooks": [
        { "type": "command", "command": "$HOME/.claude/hooks/notify.py Notification" }
      ]}
    ]
  }
}
```

#### 手动测试

```bash
echo '{"cwd":"/tmp/demo"}' | ./claude-notify/notify.py Stop
echo '{"cwd":"/tmp/demo","message":"need approval"}' | ./claude-notify/notify.py Notification

# 带 transcript 的真实模拟
echo '{"cwd":"/tmp/demo","transcript_path":"/path/to/some.jsonl"}' | ./claude-notify/notify.py Stop
```

### Windows：notify.ps1

#### 托管方式

把脚本本体放在项目里，通过 Claude Code hook 配置直接指向项目路径，避免拷贝带来的漂移。

```powershell
Test-Path "C:\path\Tools\claude-notify\notify.ps1"
```

> Windows 没有原生 symlink 体验。可在 hook 配置里直接写绝对路径，或用 `New-Item -ItemType SymbolicLink`（需管理员）。

#### hook 配置

`%USERPROFILE%\.claude\settings.json`：

```json
{
  "hooks": {
    "Stop": [
      { "matcher": "*", "hooks": [
        { "type": "command", "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File C:\\path\\Tools\\claude-notify\\notify.ps1 -Event Stop" }
      ]}
    ],
    "Notification": [
      { "matcher": "*", "hooks": [
        { "type": "command", "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File C:\\path\\Tools\\claude-notify\\notify.ps1 -Event Notification" }
      ]}
    ]
  }
}
```

> 没装 PowerShell 7 就把 `pwsh` 换成 `powershell`。

#### 通知后端 fallback 链

按以下顺序自上而下尝试，前一个失败自动降级到下一个：

1. **BurntToast**（推荐）—— 渲染最好，需先 `Install-Module BurntToast -Scope CurrentUser`
2. **WinRT Toast** —— Windows 10+ 系统自带 API
3. **Balloon Tip** —— 最后兜底，用 `System.Windows.Forms.NotifyIcon`

#### 手动测试

```powershell
'{"cwd":"C:/tmp/demo"}' | pwsh -File .\claude-notify\notify.ps1 -Event Stop
'{"cwd":"C:/tmp/demo","message":"need approval"}' | pwsh -File .\claude-notify\notify.ps1 -Event Notification
```

### 与 mac 版的差异（notify.ps1）

- 不支持 Bark 推送（如需要可自行加 `Invoke-RestMethod` 调用）
- 标题/正文裁剪在 150 字符（mac 版是 200）
- 没有 `CLAUDE_NOTIFY_OFF` 静音开关

## 环境变量

仅 `notify.py` 读以下变量；`notify.ps1` 不读环境变量。

| 变量 | 默认 | 说明 |
|------|------|------|
| `CLAUDE_NOTIFY_OFF` | — | 设 `1` 时全局静音（脚本立即 return 0） |
| `BARK_KEY` | — | Bark 设备 key；不设则跳过 Bark 推送 |
| `BARK_SERVER` | `https://api.day.app` | Bark 服务地址（自建 server 时改这个） |
| `BARK_GROUP` | `ClaudeCode` | 通知分组（Bark App 里按 group 折叠） |
| `BARK_SOUND` | `minuet` | 通知声音；Bark 内置音效列表见 [day.app 文档](https://bark.day.app/) |
| `BARK_ICON` | — | 自定义图标 URL（不设则用 Bark 默认） |
| `BARK_STOP_LEVEL` | `passive` | `Stop` 事件级别 |
| `BARK_NOTIFY_LEVEL` | `timeSensitive` | `Notification` 事件级别 |

`BARK_*_LEVEL` 取值与实际行为：

| 取值 | 行为 |
|------|------|
| `active` | 默认；亮屏推送，正常通知中心 |
| `timeSensitive` | 时效性通知，专注模式 / 勿扰下也能弹 |
| `passive` | 静默推送，仅出现在通知中心，不亮屏不响铃 |
| `critical` | 紧急推送，会绕过静音与勿扰强制响铃；需要 Bark App 在系统设置里授予"重要警报"权限 |

默认配置策略：`Stop`（任务完成）= `passive`，不打扰；`Notification`（需审批）= `timeSensitive`，确保看到。

## 示例输出

**`Stop` 事件 + 有 transcript**（macOS terminal-notifier）：

```
标题: ClaudeCode - my-project
正文: 已完成实现并通过 lint，请检查 src/components/Foo.tsx 与对应测试。
```

**`Stop` 事件 + 无 transcript**：

```
标题: ClaudeCode - my-project
正文: Task completed, please review results.
```

**`Notification` 事件**：

```
标题: ClaudeCode - Needs Attention - my-project
正文: Bash command requires permission: rm -rf node_modules
```

**手动跑空 stdin**：

```
$ echo '{}' | ./claude-notify/notify.py Stop
（无输出，弹一条标题"ClaudeCode"、正文"Task completed, please review results." 的通知）
```

**Bark 推送 payload**（POST `https://api.day.app/<BARK_KEY>`）：

```json
{"title": "ClaudeCode - my-project", "body": "Task completed, please review results.", "group": "ClaudeCode", "level": "passive", "sound": "minuet"}
```

## 故障排查

**macOS：脚本跑了不报错但通知没弹**
1. 系统设置 → 通知 → 找 `terminal-notifier`（或 `Script Editor`）→ 确认"允许通知"开着、横幅样式选"提醒"或"横幅"。
2. 勿扰 / 专注模式会拦截 `passive` 级别的通知。
3. `terminal-notifier -title test -message ok` 直接试，弹不出就是系统通知权限问题，不是脚本问题。
4. macOS 14+ 升级后 `osascript` 弹通知有时需要重新授权 `Script Editor`。
5. 默认音效是 `Glass`，被改 / 删了就静音。改 `notify.py` 里 `sound name` 为其他 `/System/Library/Sounds/` 下的名字。

**Windows：BurntToast / WinRT / Balloon 都不弹**
1. `Install-Module BurntToast -Scope CurrentUser` 装一下；装不了脚本会自动降级到 WinRT。
2. Windows 11 设置 → 通知 → 检查总开关 + "PowerShell" 或 "BurntToast" 专项允许；焦点辅助开着也会拦。
3. 用 `pwsh`（PowerShell 7）而不是老 `powershell` 5.1 跑，BurntToast 5.1 偶有兼容问题。
4. 全部失败时通常是 `pwsh` 没装 / ExecutionPolicy 限制。临时去掉脚本最后的 `try/catch` 看抛错。

**Bark 推送不到（macOS）**
1. `BARK_KEY` 没设 / 设错了。脚本检测到空 key 会**直接 return**，无报错。手测：`curl -X POST https://api.day.app/<KEY> -H 'content-type: application/json' -d '{"title":"t","body":"b"}'`。
2. `BARK_SERVER` 自建服务的话确认 https 证书可信、路径是 `/<key>` 而不是 `/push`。
3. iPhone 上 Bark 没开"允许后台推送"或被系统冻结。
4. 脚本对 Bark 调用做了 5 秒 timeout 和全局 `try/except: pass`，**不会因为 Bark 失败影响本地通知**。Bark 静默失败时如果想 debug，临时把 `send_bark_push` 里的 `except` 改成 `print`。

**hook 不触发**
1. `~/.claude/settings.json` JSON 语法错（漏逗号、多逗号），Claude Code 会静默忽略整个 hooks 段。`python3 -c 'import json; json.load(open("/path/settings.json"))'` 验证。
2. Claude Code 里 `/hooks` 命令看 hook 是否注册成功。
3. command 用绝对路径，hook 进程 `cwd` 不一定是仓库根。
4. 脚本没执行权限：`chmod +x notify.py`。

**通知正文是 `Task completed, please review results.` 而不是真实内容**
说明 transcript 解析失败：
- `transcript_path` 字段没传（旧版 Claude Code 可能不传）
- 文件路径不存在 / 没读权限
- transcript 最后 30 行里没找到 assistant 文本块
脚本对 transcript 的所有读取都 try/except，失败就回落到默认文案，**不会抛错**。

**`Event received: Stop` 这种 fallback 字符串出现在通知里**
hook 里第二个参数没传对。命令必须是 `notify.py Stop` 或 `notify.py Notification`，不能是别的事件名（如 `PreToolUse`），脚本不识别就走 else 分支显示 `Event received: <name>`。

## FAQ

**Q：Linux 能用吗？**
`notify.py` 在 Linux 上能跑，但 `terminal-notifier` 没有，`osascript` 也没有，本地通知部分两个 fallback 都失败 → 静默不弹。Bark 推送不受影响。如果你想加 Linux 后端（`notify-send`），改 `send_mac_notification` 函数加一个分支即可。

**Q：能不能不要每次任务完成都通知（短任务也弹很烦）？**
临时关：`export CLAUDE_NOTIFY_OFF=1`（仅 mac 版生效）。
长期方案：在 hook 命令里加判断，例如根据 `cwd` 过滤，或用 `transcript_path` 看 token 数判断任务长短，再决定是否调 notify.py。

**Q：能区分不同项目用不同 Bark group / sound 吗？**
能。在 hook 命令里 export 不同变量，例如 `BARK_GROUP=Tools $HOME/.claude/hooks/notify.py Stop`，也可根据 `cwd` 动态拼。

**Q：手机收 Bark 推送但 Mac 本地不弹（或反之）？**
正常，两个通道独立。本地用 `terminal-notifier`/`osascript`，Bark 走 HTTP POST，任意一个失败另一个继续。看上面"故障排查"分别 debug。

## 相关链接

- macOS 实现：[`notify.py`](https://github.com/BerBai/Tools/blob/main/claude-notify/notify.py)
- Windows 实现：[`notify.ps1`](https://github.com/BerBai/Tools/blob/main/claude-notify/notify.ps1)
- 顶层 README：[`../README.md`](https://github.com/BerBai/Tools/blob/main/README.md)
- 上游依赖：
  - [Bark](https://bark.day.app) — iOS 推送服务
  - [terminal-notifier](https://github.com/julienXX/terminal-notifier) — macOS CLI 通知工具
  - [BurntToast](https://github.com/Windos/BurntToast) — PowerShell toast 模块
  - [Claude Code Hooks](https://docs.claude.com/en/docs/claude-code/hooks) — 官方 hook 文档

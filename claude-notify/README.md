# claude-notify

Claude Code 通知 hook —— 在任务完成 / 需要审批时弹本地通知，可选推送到 [Bark](https://day.app)。

同一功能两份实现，按平台选用：

| 文件 | 适用平台 | 本地通知后端 | Bark 推送 |
|------|----------|-------------|-----------|
| `notify.py`  | macOS（也可 Linux/WSL，本地通知部分会降级失败但不报错） | `terminal-notifier` → `osascript` | ✅ |
| `notify.ps1` | Windows | BurntToast → WinRT Toast → Balloon | ❌ |

两份脚本共享同一份 stdin JSON 协议（`cwd` / `transcript_path` / `message`）和事件参数（`Stop` / `Notification`），所以 Claude Code hook 配置只是命令不同。

---

## macOS：notify.py

### 托管方式
项目内为唯一来源；`~/.claude/hooks/notify.py` 是指向本目录的 symlink：

```bash
ls -la ~/.claude/hooks/notify.py
# -> /path/Tools/claude-notify/notify.py
```

修改本文件即立即生效，无需复制或重启 Claude Code。

### hook 配置

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

### 环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `CLAUDE_NOTIFY_OFF` | — | `1` 时全局静音 |
| `BARK_KEY` | — | Bark 设备 key；不设则跳过 Bark 推送 |
| `BARK_SERVER` | `https://api.day.app` | Bark 服务地址 |
| `BARK_GROUP` | `ClaudeCode` | 通知分组 |
| `BARK_SOUND` | `minuet` | 通知声音 |
| `BARK_ICON` | — | 自定义图标 URL |
| `BARK_STOP_LEVEL` | `passive` | Stop 事件级别 |
| `BARK_NOTIFY_LEVEL` | `timeSensitive` | Notification 事件级别 |

`BARK_*_LEVEL` 取值：`active` / `timeSensitive` / `passive` / `critical`。

### 手动测试
```bash
echo '{"cwd":"/tmp/demo"}' | ./notify.py Stop
echo '{"cwd":"/tmp/demo","message":"need approval"}' | ./notify.py Notification
```

---

## Windows：notify.ps1

### 托管方式
推荐与 mac 版一致：把脚本本体放在项目里，通过 Claude Code hook 配置直接指向项目路径，避免拷贝带来的漂移。

```powershell
# 在 PowerShell 里查看路径
Test-Path "C:\path\Tools\claude-notify\notify.ps1"
```

> Windows 没有原生 symlink 体验，可在 hook 配置里直接写绝对路径，或用 `New-Item -ItemType SymbolicLink`（需管理员权限）。

### hook 配置

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

### 通知后端 fallback
1. **BurntToast**（推荐）—— 渲染最好，需先 `Install-Module BurntToast -Scope CurrentUser`
2. **WinRT Toast** —— Windows 10+ 系统自带 API
3. **Balloon Tip** —— 最后兜底，用 `System.Windows.Forms.NotifyIcon`

### 与 mac 版的差异
- 不支持 Bark 推送（如需要可自行加 `Invoke-RestMethod` 调用）
- 标题/正文裁剪在 150 字符（mac 版是 200）
- 没有 `CLAUDE_NOTIFY_OFF` 静音开关

### 手动测试
```powershell
'{"cwd":"C:/tmp/demo"}' | pwsh -File ./notify.ps1 -Event Stop
'{"cwd":"C:/tmp/demo","message":"need approval"}' | pwsh -File ./notify.ps1 -Event Notification
```

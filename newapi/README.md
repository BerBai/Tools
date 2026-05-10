# newapi

Claude Code / Anthropic SDK 与上游 anyrouter 之间的本地透明代理：解决 beta header / 请求体不兼容、空响应伪 200 等典型 gateway 坑。

## Why

直接把 `ANTHROPIC_BASE_URL` 指向 anyrouter / new-api / 其他第三方"大模型 baseurl 中转"上游时，常遇到 3 类问题：

1. **未识别的 beta 标志导致上游 panic** —— 例如 `structured-outputs-2025-12-15`、`effort-2025-11-24`，上游不认就直接 500 / 502。
2. **beta 标志和请求体字段必须配对，缺一个就崩** —— 例如带 `interleaved-thinking-2025-05-14` 但 body 里没 `thinking` 字段，上游 nil-deref 直接挂。
3. **fake-success 空响应** —— 上游偶尔返回 `2xx + content-type 正确 + 0 byte body`（典型场景：被限流、冷启动失败、配额扣完）。Anthropic SDK 默认**不重试 2xx**，于是客户端拿到一个空响应卡死。

`anyrouter_local_proxy.ts` 是一个本地 Node 透明代理：

- 监听 `127.0.0.1:$PROXY_PORT`（默认 18089，通过 `make proxy` 跑则默认 5000）
- 把请求转发到 `$MODEL_PROXY_UPSTREAM`
- **改 header**：删 `BETA_REMOVE` 集合里的 beta；删 body 里没对应字段的 paired beta
- **改 body**：当 beta 要求 `thinking` 字段但 body 没有时，注入最小合法块（`{type:"adaptive"}` 或 `{type:"enabled", budget_tokens:1024}`）
- **救援空响应**：上游 2xx + 0 字节时，重写为 502，让 SDK 触发指数回退重试
- **截短日志**：headers 里的 `authorization` / `x-api-key` / `cookie` 仅保留尾部 6 字符

对比直接连：客户端无感、SDK 不需要改一行代码、所有兼容补丁集中在一个 ts 文件，方便加 / 改 / 撤。

## 快速上手

```bash
# 仓库根目录，前台跑
make proxy UPSTREAM=https://YOUR_ANYROUTER_UPSTREAM

# 客户端把 baseurl 改成 http://127.0.0.1:5000 即可
ANTHROPIC_BASE_URL=http://127.0.0.1:5000 claude
```

> **占位 URL 说明**：`https://YOUR_ANYROUTER_UPSTREAM` 不是一个真实地址，需要替换为**你自己的** anyrouter / new-api / 其他大模型 baseurl 中转入口（私有部署、付费服务、内网代理皆可）。本仓库不提供也不内置任何具体上游 URL。

## 安装

**依赖**：
- `node` ≥ 18（用到原生 `fetch` + `ReadableStream` + `AbortController`，需要 Node 18+）
- `npx`（自带）—— 用 `npx tsx` 直接跑 ts 文件，无需预编译
- `tsx`（首次跑会自动通过 npx 拉一次）

**平台支持**：Linux / macOS / Windows（PowerShell）。

**Hook 集成**（推荐）：把 `make proxy-bg` 写进 Claude Code SessionStart hook，每次开 session 自动起代理（已在跑则跳过，不会重复起）。见下方"详细用法 → SessionStart hook 配置"。

## 详细用法

### Makefile 入口（5 个 target）

| Target | 作用 |
|--------|------|
| `make proxy` | 前台启动，日志直接打到 stderr，便于调试 |
| `make proxy-bg` | 后台启动，日志写到 `$PROXY_LOG`（默认 `/tmp/anyrouter-proxy.log`），pid 写到 `$PROXY_PID`（默认 `/tmp/anyrouter-proxy.pid`）。已在跑会直接 return 0 |
| `make proxy-stop` | 优先按 pid file 杀；没 pid file 就 `pkill -f 'tsx anyrouter_local_proxy.ts'` 兜底 |
| `make proxy-log` | `tail -f $PROXY_LOG` |
| `make proxy-status` | 看 pid file + `pgrep` 双重确认是否在跑 |

**可覆盖变量**（命令行传 / 环境变量都行）：

```bash
make proxy UPSTREAM=https://YOUR_ANYROUTER_UPSTREAM PORT=5001
make proxy-bg PROXY_LOG=/var/log/anyrouter.log
```

### 直接跑脚本

```bash
# Mac / Linux
MODEL_PROXY_UPSTREAM=https://YOUR_ANYROUTER_UPSTREAM PROXY_PORT=5000 \
  npx tsx newapi/anyrouter_local_proxy.ts

# Windows PowerShell
$env:MODEL_PROXY_UPSTREAM="https://YOUR_ANYROUTER_UPSTREAM"
$env:PROXY_PORT="5000"
npx tsx newapi/anyrouter_local_proxy.ts
```

### Claude Code 客户端配置

`~/.claude/settings.json`：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:5000",
    "MODEL_PROXY_UPSTREAM": "https://YOUR_ANYROUTER_UPSTREAM",
    "ANTHROPIC_MODEL": "claude-opus-4-7[1m]",
    "ANTHROPIC_SMALL_FAST_MODEL": "claude-haiku-4-5-20251001[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5-20251001[1m]",
    "CLAUDE_CODE_ATTRIBUTION_HEADER": "0",
    "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  },
  "model": "opus[1m]",
  "language": "Chinese",
  "awaySummaryEnabled": false
}
```

`MODEL_PROXY_UPSTREAM` 写在 `env` 里只是给 SessionStart hook 用，proxy 进程读的是它启动时所在 shell 的环境，所以 hook 命令里也得显式传一遍。

### SessionStart hook 配置（推荐）

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "pgrep -f 'tsx anyrouter_local_proxy.ts' >/dev/null || (cd /path/to/Tools/newapi && MODEL_PROXY_UPSTREAM=https://YOUR_ANYROUTER_UPSTREAM PROXY_PORT=5000 nohup npx tsx anyrouter_local_proxy.ts > /tmp/anyrouter-proxy.log 2>&1 &)"
          }
        ]
      }
    ]
  }
}
```

要点：
- `pgrep -f ... >/dev/null ||` 是幂等保护，已在跑就跳过。
- `nohup ... &` 让 proxy 跟 hook 解耦，hook 正常退出。
- `cd /path/to/Tools/newapi` 改成你机器上的实际路径。
- 路径 / 端口 / 上游若已通过 `make proxy-bg` 在跑，可以把整段 hook 换成 `cd /path/to/Tools && make proxy-bg`。

### 上游协议要求

`MODEL_PROXY_UPSTREAM` 必须是**与 Anthropic Messages API 兼容**的 baseurl，路径形态：

```
POST  $UPSTREAM/v1/messages
GET   $UPSTREAM/v1/models   (可选)
```

代理会**原样转发** path、query、绝大多数 header（去掉 `connection` / `keep-alive` / `transfer-encoding` / `content-length` / `content-encoding` 等 hop-by-hop header；`content-encoding` 必须删，因为 Node fetch 已经自动解压 body）。

## 环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `MODEL_PROXY_UPSTREAM` | （必填，未填则 `process.exit(0)`） | 上游 baseurl，结尾斜杠会被自动 trim |
| `PROXY_PORT` | `18089`（脚本默认）/ `5000`（make 默认） | 本地监听端口 |

代理还**间接消费**两组配置（在源码中是常量，需要改请直接改 `anyrouter_local_proxy.ts`）：

| 常量 | 当前值 | 含义 |
|------|------|------|
| `BETA_REMOVE` | `{structured-outputs-2025-12-15}` | 无脑删除的 beta（上游不认，加上会 panic） |
| `BETA_REQUIRES_FIELD` | `interleaved-thinking → thinking`、`context-1m → thinking`、`redact-thinking → thinking`、`context-management → context_management`、`effort → output_config` | beta 与 body 字段必须配对，缺一个就把 beta 删掉防 panic |
| `BETAS_NEED_THINKING` | `{context-1m-2025-08-07, interleaved-thinking-2025-05-14}` | 这两类 beta 出现且 body 没 thinking 时，注入最小 thinking 块 |

## 示例输出

**前台启动**：

```
$ make proxy UPSTREAM=https://YOUR_ANYROUTER_UPSTREAM
cd newapi && \
        MODEL_PROXY_UPSTREAM=https://YOUR_ANYROUTER_UPSTREAM PROXY_PORT=5000 \
        npx tsx anyrouter_local_proxy.ts
[model-proxy] http://127.0.0.1:5000 → https://YOUR_ANYROUTER_UPSTREAM
[model-proxy] strip beta=[structured-outputs-2025-12-15]
[model-proxy] inject thinking when beta has [context-1m-2025-08-07,interleaved-thinking-2025-05-14], body lacks thinking, max_tokens>=1100
```

**正常一次请求（注意 dropped/injected 标签）**：

```
[#1] --> POST /v1/messages  model=claude-opus-4-7[1m]  dropped-beta=structured-outputs-2025-12-15  injected=thinking:enabled
[#1]     headers: {"x-api-key":"<48 chars …Ab12Cd>","anthropic-beta":"context-1m-2025-08-07","host":"YOUR_ANYROUTER_UPSTREAM",...}
[#1]     body(2341B): model(20) max_tokens=8192 messages[3] thinking={"type":"enabled","budget_tokens":1024}
[#1] <-- 200
[#1] <== bytes=18432 ct=text/event-stream
```

**fake-success 触发救援**：

```
[#7] <-- 200
[#7] <== bytes=0 ct=application/json
[#7] !! empty 2xx (status=200 ct=application/json) → rewriting as 502 to trigger client retry
```

**`make proxy-status`**：

```
$ make proxy-status
proxy running, pid=12345
```

## 故障排查

**`[model-proxy] MODEL_PROXY_UPSTREAM not set, exiting`**
没设环境变量。`make proxy` 会从 Makefile 默认 `UPSTREAM=https://YOUR_ANYROUTER_UPSTREAM` 传进来，但这只是占位，需要你 `UPSTREAM=...` 显式覆盖或改 Makefile 默认值。

**客户端报 `connect ECONNREFUSED 127.0.0.1:5000`**
proxy 没起 / 起在别的端口 / 起在另一台 host。
1. `make proxy-status` 确认。
2. 客户端 `ANTHROPIC_BASE_URL` 端口对得上 `PROXY_PORT`。
3. WSL → Windows 客户端跨 host 时，不能用 `127.0.0.1`。

**所有请求都 502 / `Bad Gateway` 且日志显示 `error: fetch failed`**
本地能访问 upstream 但 fetch 失败，常见：
1. 上游 SSL 证书不受信任（自签名）：node 18+ 默认不接受，临时 `NODE_TLS_REJECT_UNAUTHORIZED=0` 跑（不安全，仅测试用）。
2. 上游 host 解析不到：`curl https://YOUR_ANYROUTER_UPSTREAM/` 验证。
3. 公司代理 / VPN 拦截：检查 `https_proxy`。

**频繁出现 `!! empty 2xx ... → rewriting as 502`**
上游真的在大量返回空响应。本地代理已经把它救成可重试错误，但如果速率很高说明上游有问题：
- 配额耗尽 / 鉴权失效 → 换 key。
- 上游冷启动 / 限流 → 联系上游。

**日志里 `streamErr=...` 出现**
上游传到一半连接断了。客户端可能拿到截断的 SSE 流。绝大多数 SDK 会自动重试，可不管；持续出现说明上游不稳。

**改了 ts 源码不生效**
`make proxy-stop && make proxy-bg` 重启。`tsx` 不会热重载。

**`anthropic-beta` 头里出现的 beta 不在 `BETA_REQUIRES_FIELD` 表里但仍 panic**
新增 beta 类型导致。改 `anyrouter_local_proxy.ts` 里 `BETA_REMOVE` 或 `BETA_REQUIRES_FIELD`，加上对应行后重启即可。

## FAQ

**Q：为什么默认端口写 5000，源码里又写 18089？**
源码默认 `PROXY_PORT=18089`，是为了避开常见占用。`make proxy` 把默认改成 5000，对齐绝大多数文档示例（README、SessionStart hook 都用 5000）。命令行覆盖优先于二者。

**Q：能不能直接把 `ANTHROPIC_BASE_URL` 指到上游不走代理？**
能，但如果上游会因为 beta header / 空响应导致客户端崩溃，你就得手动重试 / 关掉某些功能。代理就是为了把这些 workaround 集中起来。

**Q：代理会改 `x-api-key` 或泄漏 key 吗？**
不会改。日志里所有 `authorization` / `x-api-key` / `cookie` 都被 redact 成 `<N chars …xxx>` 形式，只保留长度和最后 6 字符。

**Q：能跑 N 个实例同时代理多个上游吗？**
能。每个实例用不同 `PROXY_PORT` 起就行。`make proxy-stop` 用的是固定 pid file 路径，多实例时建议 `PROXY_PID=/tmp/anyrouter-A.pid make proxy-bg PORT=5001` 这样区分。

**Q：Windows 上 `make proxy-bg` 不工作？**
Makefile 用了 bash 语法（`pgrep` / `nohup`），Windows 原生 cmd / pwsh 不支持。Windows 用：
- WSL 里跑 `make proxy-bg`，或
- pwsh 直接调 `Start-Process` 起后台 `npx tsx anyrouter_local_proxy.ts`。

## 相关链接

- 源码：[`anyrouter_local_proxy.ts`](https://github.com/BerBai/Tools/blob/main/newapi/anyrouter_local_proxy.ts)
- Makefile target：[`Makefile` → `proxy*`](https://github.com/BerBai/Tools/blob/main/Makefile)
- 顶层 README：[`../README.md`](https://github.com/BerBai/Tools/blob/main/README.md)
- 上游协议：[Anthropic Messages API](https://docs.anthropic.com/en/api/messages)
- Claude Code Hooks：[官方文档](https://docs.claude.com/en/docs/claude-code/hooks)

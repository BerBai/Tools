## 本地代理使用newapi解决子代理问题



```
{
  "env": {
    "ANTHROPIC_MODEL": "claude-opus-4-7[1m]",
    "ANTHROPIC_SMALL_FAST_MODEL": "claude-haiku-4-5-20251001[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5-20251001[1m]",
    "CLAUDE_CODE_ATTRIBUTION_HEADER": "0",
    "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1", // 4月25日测试发现需要改为0
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  },
  "model": "opus[1m]",
  "language": "Chinese",
  "awaySummaryEnabled": false

    "hooks": {
        "SessionStart": [
            {
                "matcher": "startup",
                "hooks": [
                    {
                    "type": "command", // Mac 配置
                    "command": "pgrep -f 'tsx anyrouter_local_proxy.ts' >/dev/null || (cd /path/Tools/newapi && MODEL_PROXY_UPSTREAM=https://your.upstream PROXY_PORT=5000 nohup npx tsx anyrouter_local_proxy.ts > /tmp/anyrouter-proxy.log 2>&1 &)"
                    }
                ]
            }
        ],
    }
    
```

执行以下命令，修改 API 请求地址 http://127.0.0.1:5000

```
# Windows
$env:MODEL_PROXY_UPSTREAM="https://your.upstream"; $env:PROXY_PORT="5000"; npx tsx anyrouter_local_proxy.ts

# Mac
MODEL_PROXY_UPSTREAM=https://your.upstream PROXY_PORT=5000 npx tsx anyrouter_local_proxy.ts
```

本示例中已通过 hooks 方式启动
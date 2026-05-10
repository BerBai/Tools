# Tools — 统一脚本入口
#
# 用法：make help
#
# 约定：
#   - 所有 target 都在仓库根目录跑
#   - 产物一律写到 dist/
#   - 新增脚本请同步更新 README.md 的"脚本清单"

SHELL := /usr/bin/env bash

# ---- 可覆盖参数 ----
PKG       ?= lodash@4
UPSTREAM  ?= https://your.upstream
PORT      ?= 5000
PROXY_LOG ?= /tmp/anyrouter-proxy.log
PROXY_PID ?= /tmp/anyrouter-proxy.pid

.DEFAULT_GOAL := help

# ============================================================
# 帮助
# ============================================================

.PHONY: help
help: ## 列出所有可用命令
	@echo ""
	@echo "Tools — 可用命令："
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "可覆盖变量："
	@echo "  PKG=<name@ver>      npm-bundle 打包的目标包（默认: $(PKG)）"
	@echo "  UPSTREAM=<url>      proxy 上游地址（默认: $(UPSTREAM)）"
	@echo "  PORT=<n>            proxy 监听端口（默认: $(PORT)）"
	@echo ""
	@echo "示例："
	@echo "  make npm-bundle PKG=lodash@4"
	@echo "  make proxy PORT=5001"
	@echo ""

# ============================================================
# newapi 本地代理
# ============================================================

.PHONY: proxy
proxy: ## 启动 anyrouter 本地代理（前台）
	cd newapi && \
		MODEL_PROXY_UPSTREAM=$(UPSTREAM) PROXY_PORT=$(PORT) \
		npx tsx anyrouter_local_proxy.ts

.PHONY: proxy-bg
proxy-bg: ## 后台启动代理（日志见 PROXY_LOG，默认 /tmp/anyrouter-proxy.log）
	@if [ -f $(PROXY_PID) ] && kill -0 $$(cat $(PROXY_PID)) 2>/dev/null; then \
		echo "proxy already running, pid=$$(cat $(PROXY_PID))"; \
		exit 0; \
	fi
	@cd newapi && \
		MODEL_PROXY_UPSTREAM=$(UPSTREAM) PROXY_PORT=$(PORT) \
		nohup npx tsx anyrouter_local_proxy.ts > $(PROXY_LOG) 2>&1 & \
		echo $$! > $(PROXY_PID)
	@echo "proxy started in background, pid=$$(cat $(PROXY_PID)), log=$(PROXY_LOG)"

.PHONY: proxy-stop
proxy-stop: ## 停止后台代理
	@if [ -f $(PROXY_PID) ]; then \
		kill $$(cat $(PROXY_PID)) 2>/dev/null && echo "proxy stopped" || echo "proxy not running"; \
		rm -f $(PROXY_PID); \
	else \
		pkill -f 'tsx anyrouter_local_proxy.ts' 2>/dev/null && echo "proxy killed (by name)" || echo "no proxy process found"; \
	fi

.PHONY: proxy-log
proxy-log: ## tail 代理日志
	@tail -f $(PROXY_LOG)

.PHONY: proxy-status
proxy-status: ## 查看代理是否在跑
	@if [ -f $(PROXY_PID) ] && kill -0 $$(cat $(PROXY_PID)) 2>/dev/null; then \
		echo "proxy running, pid=$$(cat $(PROXY_PID))"; \
	elif pgrep -f 'tsx anyrouter_local_proxy.ts' >/dev/null; then \
		echo "proxy running (no pid file), pids=$$(pgrep -f 'tsx anyrouter_local_proxy.ts' | tr '\n' ' ')"; \
	else \
		echo "proxy not running"; \
	fi

# ============================================================
# npm 离线打包
# ============================================================

.PHONY: npm-bundle
npm-bundle: ## 制作 npm 离线安装包（PKG=...）
	./npm-offline/npm_offline_install.sh $(PKG)

# ============================================================
# 维护
# ============================================================

.PHONY: clean
clean: ## 清理 dist/ 产物
	@rm -rf dist/npm-offline-bundle dist/npm-offline-bundle.tar.gz
	@echo "cleaned dist/"

.PHONY: clean-all
clean-all: clean proxy-stop ## 清理产物 + 停止后台进程
	@echo "all cleaned"

# ============================================================
# Pages / docs (tools.125520.xyz, GitHub Pages + just-the-docs)
# ============================================================

.PHONY: sync-docs
sync-docs: ## 把仓库根各 README 同步到 docs/<tool>.md（推 main 前手跑一次）
	@bash scripts/sync-docs.sh

.PHONY: docs-serve
docs-serve: ## 本地预览 Pages（需先 cd docs && bundle install）
	cd docs && bundle exec jekyll serve --livereload

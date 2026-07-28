# Vibe Coding — product + maintainer shortcuts
# Run `make` or `make help` for the command list.

.PHONY: help install install-dev install-cursor install-claude install-codex \
	scaffold codex-dispatch verify check-docs eval-live

HOST ?= .
PROFILE ?= detect
DRY_RUN ?=
ALLOW_PARTIAL ?=
SDD_ROOT ?= docs
DOC_ROOT ?= ./templates
UNIT ?= build
PROMPT_FILE ?=
EFFORT ?=
TIMEOUT ?=

help:
	@printf '%s\n' \
		'Vibe Coding Make targets' \
		'' \
		'Product (日常)' \
		'  make install              安装到本机已有 CLI 的端（Cursor / Claude / Codex；缺则 SKIP）' \
		'  make install-dev          同上，但 skills/templates 软链到本仓库（改 skill 少重装）' \
		'  make install-cursor       只装 Cursor' \
		'  make install-claude       只装 Claude Code' \
		'  make install-codex        只装 Codex' \
		'  make scaffold HOST=路径   AGENTS.md + SDD 文档树（PROFILE=；SDD_ROOT=docs|docs/sdd；DRY_RUN=1）' \
		'  make codex-dispatch HOST=路径 UNIT=plan|build|goal PROMPT_FILE=文件' \
		'                            CLI 派 Codex（never + 墙钟超时；防 MCP 挂死）' \
		'' \
		'Maintainer (本地私有 · 需本机有 evals/)' \
		'  make verify               一键：布局 + templates docs + routing fixtures + scaffold' \
		'  make check-docs DOC_ROOT=路径  只校验文档（默认 DOC_ROOT=./templates）' \
		'  make eval-live            Codex live 评测（需环境；--all）' \
		'' \
		'热载说明：默认 install 是拷贝；改仓库后需重新 make install（或 install-dev）。' \
		'Cursor 再 Reload Window；Claude /reload-plugins；Codex 新开任务。' \
		'evals/ plans/ minutes/ 不进入公开仓库（见 .gitignore）。'

install:
	bash scripts/install.sh

install-dev:
	bash scripts/install.sh --dev

install-cursor:
	bash scripts/install.sh cursor

install-claude:
	bash scripts/install.sh claude

install-codex:
	bash scripts/install.sh codex

scaffold:
	@extra=""; \
	if [ -n "$(PROFILE)" ]; then extra="$$extra --profile $(PROFILE)"; fi; \
	if [ -n "$(SDD_ROOT)" ]; then extra="$$extra --root $(SDD_ROOT)"; fi; \
	if [ "$(DRY_RUN)" = "1" ]; then extra="$$extra --dry-run"; fi; \
	if [ "$(ALLOW_PARTIAL)" = "1" ]; then extra="$$extra --allow-partial"; fi; \
	bash scripts/scaffold.sh "$(HOST)" $$extra

# Conductor escape hatch: wall-clock Codex dispatch (approval_policy=never).
# Example: make codex-dispatch HOST=/path/to/repo UNIT=build PROMPT_FILE=prompt.txt
codex-dispatch:
	@if [ -z "$(PROMPT_FILE)" ]; then \
		echo 'Usage: make codex-dispatch HOST=<repo> UNIT=plan|build|goal PROMPT_FILE=<file>'; \
		echo 'Optional: EFFORT=medium|high TIMEOUT=<sec>'; \
		exit 2; \
	fi
	@extra=""; \
	if [ -n "$(EFFORT)" ]; then extra="$$extra --effort $(EFFORT)"; fi; \
	if [ -n "$(TIMEOUT)" ]; then extra="$$extra --timeout $(TIMEOUT)"; fi; \
	bash skills/dispatch-codex/scripts/codex-dispatch.sh \
		--cwd "$(HOST)" --unit "$(UNIT)" $$extra -- "$$(cat "$(PROMPT_FILE)")"

verify:
	@if [ ! -f evals/verify.sh ]; then \
		echo 'SKIP: evals/ 不在公开树（本地维护者目录）。'; \
		exit 0; \
	fi
	bash evals/verify.sh

check-docs:
	@if [ ! -f evals/tools/check_docs.sh ]; then \
		echo 'SKIP: evals/ 不在公开树。'; \
		exit 0; \
	fi
	bash evals/tools/check_docs.sh "$(DOC_ROOT)"

eval-live:
	@if [ ! -f evals/tools/live_eval.py ]; then \
		echo 'SKIP: evals/ 不在公开树。'; \
		exit 0; \
	fi
	python3 evals/tools/live_eval.py --all

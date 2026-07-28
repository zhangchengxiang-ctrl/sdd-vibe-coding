# Vibe Coding — product + maintainer shortcuts
# Run `make` or `make help` for the command list.

.PHONY: help install install-dev install-cursor install-claude install-codex \
	scaffold verify check-docs eval-live

HOST ?= .
DOC_ROOT ?= ./templates

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
		'  make scaffold HOST=路径   给宿主仓生成 AGENTS.md + docs/（默认 HOST=.）' \
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
	bash scripts/scaffold.sh "$(HOST)"

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

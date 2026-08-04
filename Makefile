# Vibe Coding — product + maintainer shortcuts
# Run `make` or `make help` for the command list.

.PHONY: help install install-dev install-cursor install-claude install-codex \
	scaffold codex-dispatch wish-orchestrate context-pack verify check-docs check-spec verify-deliver \
	preflight-rail require-falsify record-falsify dispatch-gates-selftest public-gates contract-sync \
	phase3-negative eval-live eval-skill-load hooks-selftest sdd-authorize wish-journey

HOST ?= .
PROFILE ?= detect
DRY_RUN ?=
ALLOW_PARTIAL ?=
SDD_ROOT ?= docs
DOC_ROOT ?= ./templates
WITH_HOOKS ?=
SPEC ?=
UNIT ?= build
PROMPT_FILE ?=
EFFORT ?=
TIMEOUT ?=
SLICE ?=
AUTHORIZED ?=
LOG_DIR ?=
RUN_ID ?=
CMD ?=
KIND ?=
SET ?=
TRANSITION ?=
STATUS ?=
ASSERT ?=

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
		'  make scaffold HOST=路径   AGENTS.md + SDD 文档树（PROFILE=；SDD_ROOT=；WITH_HOOKS=1）' \
		'  make sdd-authorize HOST=路径 KIND=build|deploy-p4  运行时授权标记（hooks）' \
		'  make wish-journey HOST=路径 SPEC=id [STATUS=1|SET=phase|TRANSITION=phase]' \
		'  make check-spec HOST=路径 SPEC=id   Spec 静态门（事实映射/tests/架构节/run 诚实性）' \
		'  make verify-deliver HOST=路径 SPEC=id  Verify 关版门（戳 verify-deliver: ok · <时间>）' \
		'  make preflight-rail HOST=路径 [AUTHORIZED=1]  Shape 写码闸（业务 dirty 则失败）' \
		'  make codex-dispatch HOST=路径 UNIT=plan|build|goal PROMPT_FILE=文件' \
		'                            派 Codex（唯一通道；never + 墙钟；Build/Goal 需 SPEC=；Build 需 SLICE=）' \
		'  make context-pack HOST=路径 SPEC=id SLICE=S1   生成 Codex Context Pack（stdout）' \
		'  make wish-orchestrate HOST=路径 SPEC=id [SLICE=S1]  许愿：逐片 Pack→Codex Build（幂等+锁）' \
		'  make record-falsify LOG_DIR=路径 RUN_ID=id SLICE=S1 CMD="…"  结构化证伪取证' \
		'  make require-falsify LOG_DIR=路径 [RUN_ID=]  指挥侧证伪门（须 COMMAND+EXIT_CODE+VERDICT）' \
		'  make dispatch-gates-selftest  离线硬门自检（Plan / structured falsify / wish）' \
		'  make hooks-selftest       运行时 hooks + wish-journey 自检' \
		'  make public-gates         公开 CI 门（selftest+hooks+contract-sync+phase3 plugin-only）' \
		'  make phase3-negative      Phase0–2 负向验收（规则投影/写码闸/dispatch/宿主入口）' \
		'  make eval-skill-load      cursor-agent 探测：UX/Shape 是否 Read product-judgment/LOAD-MAP' \
		'' \
		'Maintainer (本地私有 · 需本机有 evals/)' \
		'  make verify               一键：布局 + templates docs + routing + check_spec fixtures + scaffold' \
		'  make check-docs DOC_ROOT=路径  只校验文档（默认 DOC_ROOT=./templates）' \
		'  make eval-live            Codex live 评测（需环境；--all）' \
		'' \
		'热载说明：默认 install 是拷贝；改仓库后需重新 make install（或 install-dev）。' \
		'Cursor 再 Reload Window；Claude /reload-plugins；Codex 新开任务。' \
		'evals/ plans/ minutes/ 不进入公开仓库（见 .gitignore）。公开克隆请跑 make public-gates。'

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
	if [ "$(WITH_HOOKS)" = "1" ]; then extra="$$extra --hooks"; fi; \
	bash scripts/scaffold.sh "$(HOST)" $$extra

# Conductor→Codex dispatch via codex-dispatch.sh.
# Example: make codex-dispatch HOST=/path/to/repo UNIT=build PROMPT_FILE=prompt.txt SPEC=spec-id
codex-dispatch:
	@if [ -z "$(PROMPT_FILE)" ]; then \
		echo 'Usage: make codex-dispatch HOST=<repo> UNIT=plan|build|goal PROMPT_FILE=<file>'; \
		echo 'Optional: EFFORT=medium|high TIMEOUT=<sec>'; \
		exit 2; \
	fi
	@extra=""; \
	if [ -n "$(EFFORT)" ]; then extra="$$extra --effort $(EFFORT)"; fi; \
	if [ -n "$(TIMEOUT)" ]; then extra="$$extra --timeout $(TIMEOUT)"; fi; \
	if [ -n "$(SPEC)" ]; then extra="$$extra --spec $(SPEC)"; fi; \
	if [ -n "$(SLICE)" ]; then extra="$$extra --slice $(SLICE)"; fi; \
	bash skills/dispatch-codex/scripts/codex-dispatch.sh \
		--cwd "$(HOST)" --unit "$(UNIT)" $$extra -- "$$(cat "$(PROMPT_FILE)")"

# Context Pack for one slice (Codex Build prompt).
# Example: make context-pack HOST=/path SPEC=my-spec SLICE=S1
context-pack:
	@if [ -z "$(SPEC)" ] || [ -z "$(SLICE)" ]; then \
		echo 'Usage: make context-pack HOST=<repo> SPEC=<id> SLICE=<S1>'; \
		exit 2; \
	fi
	python3 skills/dispatch-codex/scripts/build_context_pack.py "$(HOST)" "$(SPEC)" "$(SLICE)"

# Wish autopilot: Context Pack → Codex Build per slice.
# Example: make wish-orchestrate HOST=/path SPEC=my-spec
# Optional: SLICE=S1 EFFORT=medium|high
wish-orchestrate:
	@if [ -z "$(SPEC)" ]; then \
		echo 'Usage: make wish-orchestrate HOST=<repo> SPEC=<id> [SLICE=S1] [EFFORT=medium]'; \
		exit 2; \
	fi
	@extra=""; \
	if [ -n "$(SLICE)" ]; then extra="$$extra --slice $(SLICE)"; fi; \
	if [ -n "$(EFFORT)" ]; then extra="$$extra --effort $(EFFORT)"; fi; \
	bash skills/dispatch-codex/scripts/wish-orchestrate.sh --cwd "$(HOST)" --spec "$(SPEC)" $$extra

check-spec:
	@if [ -n "$(SPEC)" ]; then \
		bash skills/spec/scripts/check_spec.sh "$(HOST)" "$(SPEC)"; \
	else \
		bash skills/spec/scripts/check_spec.sh "$(HOST)" --all; \
	fi

verify-deliver:
	@if [ -z "$(SPEC)" ]; then \
		echo 'Usage: make verify-deliver HOST=<repo> SPEC=<id>'; \
		exit 2; \
	fi
	bash scripts/verify-deliver.sh "$(HOST)" "$(SPEC)"

preflight-rail:
	@extra=""; \
	if [ "$(AUTHORIZED)" = "1" ]; then extra="--authorized"; fi; \
	bash scripts/preflight-rail.sh --cwd "$(HOST)" $$extra

require-falsify:
	@if [ -z "$(LOG_DIR)" ]; then \
		echo 'Usage: make require-falsify LOG_DIR=<dir> [RUN_ID=]'; \
		exit 2; \
	fi
	@extra=""; \
	if [ -n "$(RUN_ID)" ]; then extra="--run-id $(RUN_ID)"; fi; \
	bash skills/dispatch-codex/scripts/require-conductor-falsify.sh --log-dir "$(LOG_DIR)" $$extra

# Record structured falsify attestation (runs CMD, writes COMMAND/EXIT_CODE/VERDICT).
# Example: make record-falsify LOG_DIR=… RUN_ID=… SLICE=S1 CMD='pytest -k s1'
record-falsify:
	@if [ -z "$(LOG_DIR)" ] || [ -z "$(RUN_ID)" ] || [ -z "$(CMD)" ]; then \
		echo 'Usage: make record-falsify LOG_DIR=<dir> RUN_ID=<id> [SLICE=S1] CMD="<falsify command>"'; \
		exit 2; \
	fi
	@extra=""; \
	if [ -n "$(SLICE)" ]; then extra="$$extra --slice $(SLICE)"; fi; \
	bash skills/dispatch-codex/scripts/record-conductor-falsify.sh \
		--log-dir "$(LOG_DIR)" --run-id "$(RUN_ID)" $$extra -- bash -c "$(CMD)"

# Offline hard-gate selftest (no Codex): Plan artifacts + structured falsify + wish status.
dispatch-gates-selftest:
	bash skills/dispatch-codex/scripts/selftest-gates.sh

# Public CI gates (no private evals/): selftest + hooks + contract-sync + phase3 plugin-only.
public-gates:
	bash scripts/public-gates.sh

contract-sync:
	bash scripts/check-contract-sync.sh

hooks-selftest:
	bash scripts/hooks/selftest-hooks.sh

# Runtime authorization markers for hooks.
# Example: make sdd-authorize HOST=. KIND=build
#          make sdd-authorize HOST=. KIND=deploy-p4
sdd-authorize:
	@if [ -z "$(KIND)" ]; then \
		echo 'Usage: make sdd-authorize HOST=<repo> KIND=build|deploy-p4'; \
		exit 2; \
	fi
	bash scripts/hooks/authorize.sh --cwd "$(HOST)" --kind "$(KIND)"

# Wish journey disk state machine.
# Examples:
#   make wish-journey HOST=. SPEC=id STATUS=1
#   make wish-journey HOST=. SPEC=id SET=design-ready
#   make wish-journey HOST=. SPEC=id TRANSITION=planning
#   make wish-journey HOST=. SPEC=id ASSERT=build
wish-journey:
	@if [ -z "$(SPEC)" ]; then \
		echo 'Usage: make wish-journey HOST=<repo> SPEC=<id> [STATUS=1|SET=phase|TRANSITION=phase|ASSERT=write|build|deploy]'; \
		exit 2; \
	fi
	@if [ "$(STATUS)" = "1" ]; then \
		bash scripts/wish-journey.sh --cwd "$(HOST)" --spec "$(SPEC)" --status; \
	elif [ -n "$(SET)" ]; then \
		bash scripts/wish-journey.sh --cwd "$(HOST)" --spec "$(SPEC)" --set "$(SET)"; \
	elif [ -n "$(TRANSITION)" ]; then \
		bash scripts/wish-journey.sh --cwd "$(HOST)" --spec "$(SPEC)" --transition "$(TRANSITION)"; \
	elif [ -n "$(ASSERT)" ]; then \
		bash scripts/wish-journey.sh --cwd "$(HOST)" --spec "$(SPEC)" --assert "$(ASSERT)"; \
	else \
		bash scripts/wish-journey.sh --cwd "$(HOST)" --spec "$(SPEC)" --status; \
	fi

phase3-negative:
	bash scripts/phase3-negative-verify.sh

eval-skill-load:
	python3 scripts/eval-skill-load-cursor.py --matrix

verify:
	@if [ ! -f evals/verify.sh ]; then \
		echo 'SKIP: evals/ 不在公开树（本地维护者目录）。跑 make public-gates 作公开门。'; \
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

# Vibe Coding — product + maintainer shortcuts
# Run `make` or `make help` for the command list.

.PHONY: help install install-dev install-cursor install-claude install-codex \
	scaffold codex-dispatch wish-orchestrate context-pack verify check-docs docs-lint docs-gen docs-lint-selftest check-spec verify-deliver close-spec close-iteration iteration-layout-selftest owners-selftest check-host-docs \
	preflight-rail codex-preflight ship oracle-migration dispatch-gates-selftest public-gates contract-sync \
	dispatch-live-lifecycle dispatch-live-scenario \
	phase3-negative eval-live eval-skill-load wish-journey \
	rot corrections host-drift single-definition orphan-refs gate-cases \
	i18n-keys adversarial-rot ship ship-selftest

HOST ?= .
PROFILE ?= detect
DRY_RUN ?=
SDD_ROOT ?= docs
DOC_ROOT ?= ./templates
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
		'  make scaffold HOST=路径   AGENTS.md + SDD 文档树（PROFILE=；SDD_ROOT=）' \
		'  make wish-journey HOST=路径 SPEC=id [STATUS=1|SET=phase|TRANSITION=phase]' \
		'  make check-spec HOST=路径 SPEC=id   Spec 静态门（事实映射/tests/架构节/run 诚实性）' \
		'  make verify-deliver HOST=路径 SPEC=id  Verify 关版门（check_spec --closing）' \
		'  make close-spec HOST=路径 SPEC=id   关版收口：verify-deliver→archived（版本内原地不动；历史 Spec 搬入 archive/）→journey' \
		'  make close-iteration HOST=路径 ITERATION=id   版本关闭：成员全关 + 复盘已写 → README 状态 archived' \
		'  make codex-preflight HOST=路径  Codex 派发环境门（trust 登记 / AGENTS 32KiB 上限 / 档位 profile）' \
		'  make preflight-rail HOST=路径 [AUTHORIZED=1]  Shape 写码闸（业务 dirty 则失败）' \
		'  make codex-dispatch HOST=路径 UNIT=build PROMPT_FILE=文件' \
		'                            派 eligible 切片（越界禁派；never + 墙钟；需 SPEC= SLICE=）' \
		'  make context-pack HOST=路径 SPEC=id SLICE=S1   生成 Codex Context Pack（stdout）' \
		'  make wish-orchestrate HOST=路径 SPEC=id [SLICE=S1]  许愿：打包 D→edit-wave Codex（可并行；幂等+锁）' \
		'  make ship HOST=路径 SPEC=id [SLICE=S1] META=…  红绿 replay（基线红→改后绿）' \
		'  make oracle-migration HOST=路径 [ARCHIVED=1] [CSV=1]  还有多少 P0 Oracle runner 跑不了' \
		'  make dispatch-gates-selftest  离线硬门自检（Plan / oracle replay / wish）' \
		'  make dispatch-live-lifecycle  真机 codex exec 生命周期自检（烧 token）' \
		'  make dispatch-live-scenario   真机多 D DAG 场景自检（烧 token）' \
		'  make gate-cases            91 例门强度回测目录 + live 探针' \
		'  make public-gates         公开 CI 门（selftest+contract-sync+phase3+rot；报告 single-def/orphan）' \
		'  make rot                  腐烂度量（预算上限=基线；禁止回升）' \
		'  make corrections          本机 transcript 纠正信号 → M1/M2/M3 桶（纯本地）' \
		'  make host-drift           可选：外部宿主仓漂移（不进 public-gates）' \
		'  make phase3-negative      Phase0–2 负向验收（规则投影/写码闸/dispatch）' \
		'  make eval-skill-load      cursor-agent 探测：UX/Shape 是否 Read product-judgment/LOAD-MAP' \
		'  make eval-explore-substance  cursor-agent 探测：Explore 产出实质 vs 表演卡片' \
		'  make verify-explore-deliver  静态+ship+phase3+skill-load+substance 一键验收' \
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
	bash scripts/scaffold.sh "$(HOST)" $$extra

# Conductor→Codex dispatch via codex-dispatch.sh.
# Example: make codex-dispatch HOST=/path/to/repo UNIT=build PROMPT_FILE=prompt.txt SPEC=spec-id
codex-dispatch:
	@if [ -z "$(PROMPT_FILE)" ]; then \
		echo 'Usage: make codex-dispatch HOST=<repo> UNIT=build PROMPT_FILE=<file>'; \
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

# Wish autopilot: pack A→D → edit-wave Codex Build (parallel 1–4).
# Example: make wish-orchestrate HOST=/path SPEC=my-spec
# Optional: SLICE=S1 EFFORT=medium|high PARALLEL=2
wish-orchestrate:
	@if [ -z "$(SPEC)" ]; then \
		echo 'Usage: make wish-orchestrate HOST=<repo> SPEC=<id> [SLICE=S1] [EFFORT=medium] [PARALLEL=2]'; \
		exit 2; \
	fi
	@extra=""; \
	if [ -n "$(SLICE)" ]; then extra="$$extra --slice $(SLICE)"; fi; \
	if [ -n "$(EFFORT)" ]; then extra="$$extra --effort $(EFFORT)"; fi; \
	if [ -n "$(PARALLEL)" ]; then extra="$$extra --parallel $(PARALLEL)"; fi; \
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

close-spec:
	@if [ -z "$(SPEC)" ]; then \
		echo 'Usage: make close-spec HOST=<repo> SPEC=<id> [SKIP_VD=1]'; \
		exit 2; \
	fi
	@extra=""; \
	if [ "$(SKIP_VD)" = "1" ]; then extra="--skip-verify-deliver"; fi; \
	bash scripts/close-spec.sh "$(HOST)" "$(SPEC)" $$extra

close-iteration:
	@if [ -z "$(ITERATION)" ]; then \
		echo 'Usage: make close-iteration HOST=<repo> ITERATION=<id>'; \
		exit 2; \
	fi
	bash scripts/close-iteration.sh "$(HOST)" "$(ITERATION)"

iteration-layout-selftest:
	bash scripts/selftest-iteration-layout.sh

owners-selftest:
	bash scripts/selftest-owners.sh

codex-preflight:
	bash scripts/codex-preflight.sh --cwd "$(HOST)"

preflight-rail:
	@extra=""; \
	if [ "$(AUTHORIZED)" = "1" ]; then extra="--authorized"; fi; \
	bash scripts/preflight-rail.sh --cwd "$(HOST)" $$extra


# Offline hard-gate selftest (no Codex): Plan artifacts + Oracle replay + wish status.
close-spec-selftest:
	bash scripts/selftest-close-spec.sh

# Read-only docs consistency check of a host: make check-host-docs HOST=/path [MAX_BROKEN=N]
# (named apart from the maintainer target `check-docs` below, which it used to shadow silently)
check-host-docs:
	@if [ -z "$(HOST)" ]; then echo 'Usage: make check-host-docs HOST=<repo> [MAX_BROKEN=N]'; exit 2; fi
	bash scripts/check-docs.sh "$(HOST)" $(if $(MAX_BROKEN),--max-broken $(MAX_BROKEN))

docs-system-selftest:
	bash scripts/selftest-docs-system.sh

# Docs lint / generate / move for a host (C1..C10, generated sections): see scripts/sdd_docs.py
docs-lint:
	@if [ -z "$(HOST)" ]; then echo 'Usage: make docs-lint HOST=<repo>'; exit 2; fi
	python3 scripts/sdd_docs.py check "$(HOST)"

docs-gen:
	@if [ -z "$(HOST)" ]; then echo 'Usage: make docs-gen HOST=<repo>'; exit 2; fi
	python3 scripts/sdd_docs.py gen "$(HOST)"

docs-lint-selftest:
	bash scripts/selftest-docs-lint.sh

dispatch-gates-selftest:
	bash skills/dispatch-codex/scripts/selftest-gates.sh

# Red-green replay of the frozen Oracles. --from-meta reads the baseline SHA the dispatch
# recorded, so nobody has to remember which tree predates the change.
#   make ship HOST=~/code/agentdeck SPEC=my-spec SLICE=S1 \
#     META=~/code/agentdeck/.codex-dispatch-logs/<run-id>.meta.txt
# BASE= alone is refused: letting the judged party pick its baseline makes red-green a
# formality. SHIP_ALLOW_MANUAL_BASE=1 permits it and marks the evidence unverified.
ship:
	bash skills/dispatch-codex/scripts/ship.sh --host $(HOST) --spec $(SPEC) \
	  $(if $(SLICE),--slice $(SLICE),) $(if $(BASE),--base $(BASE),) \
	  $(if $(META),--from-meta $(META),) $(if $(PHASE),--phase $(PHASE),)

ship-selftest:
	bash skills/dispatch-codex/scripts/selftest-ship.sh

# LIVE selftests: real `codex exec` in an isolated /tmp host. Burn real tokens,
# need `codex` on PATH + auth, and are the only end-to-end check of dispatch.
dispatch-live-lifecycle:
	bash skills/dispatch-codex/scripts/selftest-codex-lifecycle-live.sh

dispatch-live-scenario:
	bash skills/dispatch-codex/scripts/selftest-codex-scenario-live.sh

# Public CI gates (no private evals/): selftest + contract-sync + phase3 + rot.
public-gates:
	bash scripts/public-gates.sh

contract-sync:
	bash scripts/check-contract-sync.sh

gate-cases:
	bash scripts/gate-cases-runner.sh

# Migration meter, not a gate: how many P0 Oracles a runner still cannot execute. The gates
# refuse them where it matters; this makes the remaining bill visible per Spec.
#   make oracle-migration HOST=~/code/agentdeck [ARCHIVED=1] [CSV=1]
oracle-migration:
	@extra=""; \
	if [ "$(ARCHIVED)" = "1" ]; then extra="$$extra --archived"; fi; \
	if [ "$(CSV)" = "1" ]; then extra="$$extra --csv"; fi; \
	bash scripts/oracle-migration.sh --cwd "$(HOST)" $$extra

# Rot budget meter. Ceiling = scripts/rot-baseline.json (ratchet: only lower).
rot:
	bash scripts/rot-meter.sh

# Local transcript correction buckets (M1/M2/M3). Not a CI gate.
corrections:
	bash scripts/corrections.sh

# Optional host-repo drift (agentdeck / bi / datasage). Not in public-gates.
host-drift:
	bash scripts/host-drift.sh

single-definition:
	bash scripts/single-definition.sh

orphan-refs:
	bash scripts/orphan-refs.sh

# i18n key existence against a host repo. The cheapest reality anchor there is:
# an implementation shipped hardcoded English to Chinese users while a 368-line
# acceptance suite passed, because it referenced keys that existed in no locale
# and masked them with i18n's own `defaultValue`.
#   make i18n-keys HOST=~/code/agentdeck          # findings, exit 1 on masked keys
#   make i18n-keys HOST=~/code/agentdeck STRICT=1 # also fail on partial locales
i18n-keys:
	bash scripts/check-i18n-keys.sh --cwd $(HOST) $(if $(STRICT),--strict,)

# Destructive/adversarial capability tests for the rot mechanisms (16 attacks).
# NOT in public-gates: it runs public-gates itself, so nesting it would recurse.
adversarial-rot:
	bash scripts/adversarial-rot-verify.sh

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

eval-explore-substance:
	python3 scripts/eval-explore-substance.py

verify-explore-deliver:
	bash scripts/verify-explore-deliver.sh

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

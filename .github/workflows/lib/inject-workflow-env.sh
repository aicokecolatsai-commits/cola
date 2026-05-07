#!/usr/bin/env bash
# inject-workflow-env.sh
#
# 【用途】
#   安裝 skill 時，將技能所需的 secret 環境變數注入到 issue-N.yml 的兩個位置：
#
#   注入點 1 — 頂層 env: 區塊（從 GitHub Secret 讀值）：
#     env:
#       OPENAI_API_KEY: "${{ secrets.OPENAI_API_KEY }}"   ← 新增
#
#   注入點 2 — 指定 step 的 env: 區塊（從頂層 env 繼承值）：
#     - id: <step-id>
#       env:
#         OPENAI_API_KEY: ${{ env.OPENAI_API_KEY }}       ← 新增
#
# 【資料來源】
#   技能的 githubclaw.json 裡的 requireEnv 陣列（由 skills.yml Step 4 讀取）
#   經 skills.yml Step 4 轉成逗號分隔字串，存入 $REQUIRED_ENVS，再傳給本腳本。
#
# 【idempotent】
#   已存在的 key 不會重複插入，可安全重跑。
#
# 【實作策略】
#   使用 Python3（ubuntu-latest 內建，無需安裝任何套件）逐行解析 YAML。
#   逐行處理可保留所有原始註解與縮排格式（PyYAML round-trip 會破壞註解）。
#
# 用法:
#   inject-workflow-env.sh <workflow-file> <VAR1,VAR2,...> [step-id]
#
#   step-id 預設為 "copilot_task"（issue-N.yml 的主要執行 step）

set -euo pipefail

WORKFLOW_FILE="${1:?Usage: inject-workflow-env.sh <workflow-file> <env-vars> [step-id]}"
ENV_VARS_RAW="${2:?Usage: inject-workflow-env.sh <workflow-file> <env-vars> [step-id]}"
STEP_ID="${3:-copilot_task}"

python3 - "$WORKFLOW_FILE" "$ENV_VARS_RAW" "$STEP_ID" <<'PYEOF'
import sys, re

def inject(workflow_file, env_vars_raw, step_id):
    # 將逗號分隔字串轉成 list，過濾掉非法識別字
    env_vars = [
        v.strip() for v in env_vars_raw.split(',')
        if v.strip() and re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', v.strip())
    ]
    if not env_vars:
        print("⚠️  No valid env vars found, nothing to do")
        return

    with open(workflow_file, 'r') as f:
        lines = f.readlines()

    # ── 注入點 1：頂層 env: 區塊 ──────────────────────────────────────
    # 掃描所有行，找到 "env:"（頂層，無縮排），
    # 接著收集其下 2 空格縮排的 KEY: 行，記錄最後一個 KEY 的位置，
    # 新 key 插入在最後一個現有 key 之後。
    top_keys = set()
    top_insert_after = None
    in_top_env = False
    for i, line in enumerate(lines):
        stripped = line.rstrip()
        if stripped == 'env:':
            in_top_env = True
            continue
        if in_top_env:
            # 遇到其他頂層 key（無縮排、非空白、非註解）代表 env 區塊結束
            if stripped and not stripped[0].isspace() and not stripped.startswith('#'):
                in_top_env = False
                continue
            m = re.match(r'^  ([A-Za-z_][A-Za-z0-9_]*):', line)
            if m:
                top_keys.add(m.group(1))
                top_insert_after = i

    top_to_add = [v for v in env_vars if v not in top_keys]
    if top_to_add and top_insert_after is not None:
        # 格式：  VAR: "${{ secrets.VAR }}"
        new_lines = [f'  {v}: "${{{{ secrets.{v} }}}}"\n' for v in top_to_add]
        lines[top_insert_after + 1:top_insert_after + 1] = new_lines
        print(f'✅ Added to top-level env: {", ".join(top_to_add)}')
    elif not top_to_add:
        print('ℹ️  Top-level env: no new vars (all already present)')
    else:
        print('⚠️  Top-level env block not found')

    # ── 注入點 2：指定 step 的 env: 區塊 ──────────────────────────────
    # 先找到 "id: <step_id>" 那一行，記下其縮排深度（即 step 屬性的縮排層）。
    # 再往下掃描找到同層的 "env:" 區塊，收集已有的 key，
    # 新 key 插入在最後一個現有 key 之後。
    step_line_idx = None
    for i, line in enumerate(lines):
        if re.search(rf'\bid:\s*{re.escape(step_id)}\b', line):
            step_line_idx = i
            break

    if step_line_idx is None:
        print(f'⚠️  Step with id "{step_id}" not found — step-level env not injected')
        with open(workflow_file, 'w') as f:
            f.writelines(lines)
        return

    # id: 與 env: 在 YAML step 裡是同層屬性，縮排相同
    step_indent = len(lines[step_line_idx]) - len(lines[step_line_idx].lstrip())
    env_block_indent = step_indent       # env: 與 id: 同縮排
    var_indent = step_indent + 2         # env 區塊內的 KEY: 再縮排 2

    step_keys = set()
    step_insert_after = None
    in_step_env = False
    for i in range(step_line_idx + 1, min(step_line_idx + 80, len(lines))):
        line = lines[i]
        if not line.strip():
            continue
        cur_indent = len(line) - len(line.lstrip())
        # 遇到下一個 step 的 "-" 起始行，代表已離開此 step
        if cur_indent <= step_indent and line.lstrip().startswith('-'):
            break
        if re.match(r'\s+env:\s*$', line) and cur_indent == env_block_indent:
            in_step_env = True
            continue
        if in_step_env:
            # 縮排回退代表 env 區塊結束
            if cur_indent < var_indent:
                break
            m = re.match(r'\s+([A-Za-z_][A-Za-z0-9_]*):', line)
            if m:
                step_keys.add(m.group(1))
                step_insert_after = i

    step_to_add = [v for v in env_vars if v not in step_keys]
    if step_to_add and step_insert_after is not None:
        # 格式：        VAR: ${{ env.VAR }}（從頂層 env 繼承，不用 secrets）
        prefix = ' ' * var_indent
        new_lines = [f'{prefix}{v}: ${{{{ env.{v} }}}}\n' for v in step_to_add]
        lines[step_insert_after + 1:step_insert_after + 1] = new_lines
        print(f'✅ Added to step "{step_id}" env: {", ".join(step_to_add)}')
    elif not step_to_add:
        print(f'ℹ️  Step "{step_id}" env: no new vars (all already present)')
    else:
        print(f'⚠️  Step "{step_id}" env block not found')

    with open(workflow_file, 'w') as f:
        f.writelines(lines)

inject(sys.argv[1], sys.argv[2], sys.argv[3])
PYEOF

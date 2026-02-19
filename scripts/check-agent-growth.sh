#!/usr/bin/env bash
# ==============================================================================
# check-agent-growth.sh
#
# 診斷 agent workspace 的成長系統健康度。
# 輸出：各項指標的狀態（✅ / ⚠️ / ❌）+ 改善建議。
#
# 用法:
#   ./scripts/check-agent-growth.sh [WORKSPACE_DIR]
#   ./scripts/check-agent-growth.sh --all   # 檢查所有 agents
#
# 預設 WORKSPACE_DIR: ~/.openclaw/workspace
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_DIR="${OPENCLAW_DIR:-$HOME/.openclaw}"
AGENTS_DIR="$OPENCLAW_DIR/agents"

# ── 引數解析 ────────────────────────────────────────────────────────────────
CHECK_ALL=false
WORKSPACE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)  CHECK_ALL=true; shift ;;
    -h|--help)
      echo "Usage: $0 [WORKSPACE_DIR | --all]"
      echo "  Default workspace: ~/.openclaw/workspace"
      exit 0 ;;
    *)  WORKSPACE="$1"; shift ;;
  esac
done

# ── 顏色 ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
  BOLD='\033[1m'; RESET='\033[0m'; DIM='\033[2m'
else
  GREEN=''; YELLOW=''; RED=''; BOLD=''; RESET=''; DIM=''
fi

ok()   { echo -e "  ${GREEN}✅${RESET} $*"; }
warn() { echo -e "  ${YELLOW}⚠️  ${RESET}$*"; }
fail() { echo -e "  ${RED}❌${RESET} $*"; }
info() { echo -e "  ${DIM}   $*${RESET}"; }

# ── 核心診斷函式 ─────────────────────────────────────────────────────────────
check_workspace() {
  local ws="$1"
  local label="${2:-workspace}"

  echo ""
  echo -e "${BOLD}── $label ──${RESET}"
  echo -e "${DIM}   $ws${RESET}"

  local score=0
  local total=0
  local suggestions=()

  # ── 1. 核心身份檔案 ──────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}核心檔案${RESET}"

  for f in SOUL.md USER.md IDENTITY.md MEMORY.md AGENTS.md; do
    (( total++ ))
    if [[ -f "$ws/$f" ]]; then
      local lines
      lines=$(wc -l < "$ws/$f" 2>/dev/null || echo 0)
      if (( lines > 5 )); then
        ok "$f  ${DIM}(${lines}行)${RESET}"
        (( score++ ))
      else
        warn "$f 存在但內容過少 (${lines}行) — 可能是空模板"
        suggestions+=("填充 $f（目前只有 ${lines} 行）")
      fi
    else
      fail "$f 不存在"
      suggestions+=("建立 $f — 使用 docs/reference/templates/$f 為基礎")
    fi
  done

  # ── 2. 成長系統檔案 ──────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}成長系統${RESET}"

  # GROWTH_LOG.md
  (( total++ ))
  if [[ -f "$ws/GROWTH_LOG.md" ]]; then
    local entries
    entries=$(grep -c "^### [0-9]\{4\}" "$ws/GROWTH_LOG.md" 2>/dev/null || echo 0)
    if (( entries > 0 )); then
      ok "GROWTH_LOG.md  ${DIM}(${entries} 條記錄)${RESET}"
      (( score++ ))
    else
      warn "GROWTH_LOG.md 存在但沒有記錄 — 還沒開始追蹤失誤"
      suggestions+=("在 GROWTH_LOG.md 記錄第一條失誤或里程碑")
    fi
  else
    fail "GROWTH_LOG.md 不存在"
    suggestions+=("執行: ./scripts/init-agent-growth.sh $ws")
  fi

  # bank/ 目錄
  (( total++ ))
  if [[ -d "$ws/bank" ]]; then
    local bank_files
    bank_files=$(find "$ws/bank" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    local bank_entities
    bank_entities=$(find "$ws/bank/entities" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

    local bank_content=0
    for bf in world.md experience.md opinions.md; do
      if [[ -f "$ws/bank/$bf" ]]; then
        local blines
        blines=$(wc -l < "$ws/bank/$bf" 2>/dev/null || echo 0)
        (( blines > 10 )) && (( bank_content++ ))
      fi
    done

    if (( bank_content >= 2 )); then
      ok "bank/  ${DIM}(${bank_files} 個檔案，${bank_entities} 個實體)${RESET}"
      (( score++ ))
    elif (( bank_files > 0 )); then
      warn "bank/ 存在但內容稀少 (${bank_content}/3 個核心檔案有內容)"
      suggestions+=("填充 bank/world.md、bank/experience.md — 記錄環境事實和活動")
    else
      warn "bank/ 目錄為空"
      suggestions+=("執行: ./scripts/init-agent-growth.sh $ws")
    fi
  else
    fail "bank/ 目錄不存在"
    suggestions+=("執行: ./scripts/init-agent-growth.sh $ws")
  fi

  # HEARTBEAT.md
  (( total++ ))
  if [[ -f "$ws/HEARTBEAT.md" ]]; then
    if grep -q "成長版\|weekly\|Weekly\|週" "$ws/HEARTBEAT.md" 2>/dev/null; then
      ok "HEARTBEAT.md  ${DIM}(含週度反思指令)${RESET}"
      (( score++ ))
    else
      warn "HEARTBEAT.md 存在但無週度反思指令"
      suggestions+=("考慮升級 HEARTBEAT.md 為成長版 (docs/reference/templates/HEARTBEAT.growth.md)")
    fi
  else
    fail "HEARTBEAT.md 不存在 — heartbeat 無法觸發任何行動"
    suggestions+=("建立 HEARTBEAT.md — 從 docs/reference/templates/HEARTBEAT.growth.md 複製")
  fi

  # ── 3. 週度反思活躍度 ────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}週度反思活躍度${RESET}"

  (( total++ ))
  if [[ -f "$ws/GROWTH_LOG.md" ]]; then
    # 最後一次反思日期（從 GROWTH_LOG 中找日期）
    local last_entry
    last_entry=$(grep -o "^### [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" "$ws/GROWTH_LOG.md" 2>/dev/null \
                 | tail -1 | grep -o "[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" || echo "")

    if [[ -n "$last_entry" ]]; then
      local today
      today=$(date +%Y-%m-%d)
      # 計算天數差（用 python 避免 date 指令的跨平台問題）
      local days_ago
      days_ago=$(python3 -c "
from datetime import date
d = date.fromisoformat('$last_entry')
t = date.today()
print((t - d).days)
" 2>/dev/null || echo "?")

      if [[ "$days_ago" == "?" ]]; then
        ok "GROWTH_LOG 最後更新：$last_entry"
        (( score++ ))
      elif (( days_ago <= 7 )); then
        ok "GROWTH_LOG 最後更新：$last_entry  ${DIM}(${days_ago} 天前)${RESET}"
        (( score++ ))
      elif (( days_ago <= 21 )); then
        warn "GROWTH_LOG 最後更新：$last_entry  ${DIM}(${days_ago} 天前 — 快要超過週度節奏)${RESET}"
        suggestions+=("本週執行一次 growth-reflect（上次反思距今 ${days_ago} 天）")
      else
        fail "GROWTH_LOG 最後更新：$last_entry  (${days_ago} 天前 — 反思週期中斷)"
        suggestions+=("立即執行 growth-reflect（上次反思距今 ${days_ago} 天）")
      fi
    else
      warn "GROWTH_LOG 沒有日期記錄"
      (( score++ )) # 有檔案就給分，已在上面扣了
    fi
  else
    info "（GROWTH_LOG.md 不存在，跳過）"
  fi

  # ── 4. 記憶活躍度 ────────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}記憶活躍度${RESET}"

  (( total++ ))
  if [[ -d "$ws/memory" ]]; then
    local recent_notes
    recent_notes=$(find "$ws/memory" -name "*.md" -newer "$ws/memory" -mtime -14 2>/dev/null | wc -l | tr -d ' ')
    local total_notes
    total_notes=$(find "$ws/memory" -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md" 2>/dev/null | wc -l | tr -d ' ')

    if (( total_notes >= 14 )); then
      ok "memory/  ${DIM}(共 ${total_notes} 個日記，最近 14 天有 ${recent_notes} 個)${RESET}"
      (( score++ ))
    elif (( total_notes >= 3 )); then
      warn "memory/ 記錄稀少  ${DIM}(共 ${total_notes} 個日記)${RESET}"
      suggestions+=("確認 agent 每天在 memory/ 寫日記")
    else
      fail "memory/ 幾乎沒有日記  (${total_notes} 個)"
      suggestions+=("確認 heartbeat 是否正常運行，agent 應每日寫 memory/*.md")
    fi
  else
    fail "memory/ 目錄不存在"
    suggestions+=("建立 memory/ 目錄，agent 下次 session 應開始寫日記")
  fi

  # ── 5. Skills 狀態 ───────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}技能庫${RESET}"

  local repo_root
  repo_root="$(cd "$SCRIPT_DIR/.." && pwd)"
  local skills_dir="$repo_root/.agents/skills"

  if [[ -d "$skills_dir" ]]; then
    local skill_count
    skill_count=$(find "$skills_dir" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    ok ".agents/skills/  ${DIM}(${skill_count} 個技能)${RESET}"
  else
    warn ".agents/skills/ 不存在"
  fi

  # ── 6. 摘要 ──────────────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}─────────────────────────────────${RESET}"

  local pct=$(( score * 100 / total ))
  local grade
  if   (( pct >= 80 )); then grade="${GREEN}健康 🌱${RESET}"
  elif (( pct >= 50 )); then grade="${YELLOW}發育中 🌿${RESET}"
  else                       grade="${RED}需要關注 🪴${RESET}"
  fi

  echo -e "  成長健康度：${score}/${total}  ($pct%)  →  $(echo -e $grade)"

  if (( ${#suggestions[@]} > 0 )); then
    echo ""
    echo -e "  ${BOLD}建議行動：${RESET}"
    for s in "${suggestions[@]}"; do
      echo -e "  ${YELLOW}→${RESET} $s"
    done
  fi
  echo ""
}

# ── 主程式 ───────────────────────────────────────────────────────────────────
echo -e "${BOLD}Agent Growth Health Check${RESET}"
echo -e "${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"

if $CHECK_ALL; then
  if [[ ! -d "$AGENTS_DIR" ]]; then
    echo "❌ 找不到 $AGENTS_DIR"
    exit 1
  fi
  found=0
  while IFS= read -r -d '' agent_dir; do
    ws="$agent_dir/workspace"
    if [[ -d "$ws" ]]; then
      agent_id="$(basename "$agent_dir")"
      check_workspace "$ws" "Agent: $agent_id"
      (( found++ ))
    fi
  done < <(find "$AGENTS_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

  if (( found == 0 )); then
    echo ""
    echo "⚠️  在 $AGENTS_DIR 中找不到含 workspace/ 的 agent。"
    echo "   如果 workspace 路徑不同，請直接指定："
    echo "   $0 /path/to/workspace"
  fi
else
  ws="${WORKSPACE:-$HOME/.openclaw/workspace}"
  check_workspace "$ws"
fi

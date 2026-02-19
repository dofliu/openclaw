#!/usr/bin/env bash
# ==============================================================================
# bank-diff.sh
#
# 對比 agent 知識庫（bank/）的兩個版本，顯示知識如何演化。
# 來源：agent-backups/<agentId>/bank/ (備份) vs ~/.openclaw/.../bank/ (現況)
#
# 用法:
#   ./scripts/bank-diff.sh [OPTIONS]
#
# 選項:
#   --agent <agentId>     指定 agent（預設：最近一個有備份的 agent）
#   --backup <date>       與哪個備份日期比較（預設：最舊的備份）
#   --workspace <path>    workspace 路徑（預設：~/.openclaw/workspace）
#   --stat                只顯示統計，不顯示逐行 diff
#   --file <filename>     只比較特定檔案（例：world.md）
#   -h, --help            顯示說明
#
# 範例:
#   ./scripts/bank-diff.sh
#   ./scripts/bank-diff.sh --stat
#   ./scripts/bank-diff.sh --file opinions.md
#   ./scripts/bank-diff.sh --agent abc123 --backup 2026-01-15
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OPENCLAW_DIR="${OPENCLAW_DIR:-$HOME/.openclaw}"
BACKUP_DIR="$REPO_ROOT/agent-backups"

# ── 引數解析 ────────────────────────────────────────────────────────────────
AGENT_ID=""
BACKUP_DATE=""
WORKSPACE=""
STAT_ONLY=false
FILTER_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)     AGENT_ID="$2"; shift 2 ;;
    --backup)    BACKUP_DATE="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --stat)      STAT_ONLY=true; shift ;;
    --file)      FILTER_FILE="$2"; shift 2 ;;
    -h|--help)
      sed -n '/^# ==/,/^# ==/p' "$0" | sed 's/^# \{0,2\}//'
      exit 0 ;;
    *) echo "未知選項: $1" >&2; exit 1 ;;
  esac
done

# ── 顏色 ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
  BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'; CYAN='\033[0;36m'
else
  GREEN=''; RED=''; YELLOW=''; BOLD=''; DIM=''; RESET=''; CYAN=''
fi

# ── 解析 agent 和 workspace ──────────────────────────────────────────────────

# 取得 workspace 中的 bank/
resolve_workspace_bank() {
  if [[ -n "$WORKSPACE" ]]; then
    echo "$WORKSPACE/bank"
    return
  fi

  # 若有指定 agent，找 agent workspace
  if [[ -n "$AGENT_ID" ]]; then
    local ws="$OPENCLAW_DIR/agents/$AGENT_ID/workspace/bank"
    if [[ -d "$ws" ]]; then echo "$ws"; return; fi
  fi

  # 嘗試 ~/.openclaw/workspace（單 agent 常見路徑）
  if [[ -d "$OPENCLAW_DIR/workspace/bank" ]]; then
    echo "$OPENCLAW_DIR/workspace/bank"
    return
  fi

  # 找第一個有 bank/ 的 agent
  local found
  found=$(find "$OPENCLAW_DIR/agents" -maxdepth 3 -type d -name "bank" 2>/dev/null | head -1)
  if [[ -n "$found" ]]; then echo "$found"; return; fi

  echo ""
}

# 取得備份中的 bank/（以 git 歷史為來源）
resolve_backup_bank() {
  local agent_id="$1"

  # 找 agent-backups/<agentId>/bank/
  if [[ -n "$agent_id" ]]; then
    local bak="$BACKUP_DIR/$agent_id/bank"
    if [[ -d "$bak" ]]; then echo "$bak"; return; fi
  fi

  # 找任何 agent 的備份 bank/
  local found
  found=$(find "$BACKUP_DIR" -maxdepth 3 -type d -name "bank" 2>/dev/null | head -1)
  if [[ -n "$found" ]]; then echo "$found"; return; fi

  echo ""
}

# ── 計算 diff 統計 ────────────────────────────────────────────────────────────
diff_stat() {
  local old_dir="$1"
  local new_dir="$2"
  local file_filter="$3"

  local added=0 removed=0 changed=0 new_files=0 del_files=0

  # 找所有 .md 檔案
  declare -A old_files new_files_map
  while IFS= read -r f; do
    [[ -n "$f" ]] && old_files["${f#"$old_dir/"}"]="$f"
  done < <(find "$old_dir" -name "*.md" 2>/dev/null)
  while IFS= read -r f; do
    [[ -n "$f" ]] && new_files_map["${f#"$new_dir/"}"]="$f"
  done < <(find "$new_dir" -name "*.md" 2>/dev/null)

  echo ""
  echo -e "${BOLD}── 知識演化統計 ──${RESET}"
  echo ""

  # 新增的檔案
  for rel in "${!new_files_map[@]}"; do
    [[ -n "$file_filter" && "$rel" != *"$file_filter"* ]] && continue
    if [[ -z "${old_files[$rel]+x}" ]]; then
      local lines
      lines=$(wc -l < "${new_files_map[$rel]}" 2>/dev/null || echo 0)
      echo -e "  ${GREEN}+ 新檔案${RESET}  $rel  ${DIM}(${lines} 行)${RESET}"
      (( new_files++ ))
    fi
  done

  # 刪除的檔案
  for rel in "${!old_files[@]}"; do
    [[ -n "$file_filter" && "$rel" != *"$file_filter"* ]] && continue
    if [[ -z "${new_files_map[$rel]+x}" ]]; then
      echo -e "  ${RED}- 已刪除${RESET}  $rel"
      (( del_files++ ))
    fi
  done

  # 已變更的檔案
  for rel in "${!new_files_map[@]}"; do
    [[ -n "$file_filter" && "$rel" != *"$file_filter"* ]] && continue
    if [[ -n "${old_files[$rel]+x}" ]]; then
      local old_f="${old_files[$rel]}"
      local new_f="${new_files_map[$rel]}"
      if ! cmp -s "$old_f" "$new_f"; then
        local a r
        a=$(diff "$old_f" "$new_f" 2>/dev/null | grep "^>" | wc -l | tr -d ' ')
        r=$(diff "$old_f" "$new_f" 2>/dev/null | grep "^<" | wc -l | tr -d ' ')
        echo -e "  ${YELLOW}~ 已變更${RESET}  $rel  ${DIM}(+${a} -${r} 行)${RESET}"
        (( added += a, removed += r, changed++ ))
      fi
    fi
  done

  echo ""
  echo -e "  新檔案 ${GREEN}+${new_files}${RESET}  刪除 ${RED}-${del_files}${RESET}  變更 ${YELLOW}~${changed}${RESET}"
  echo -e "  新增行數 ${GREEN}+${added}${RESET}  刪除行數 ${RED}-${removed}${RESET}"
  echo ""
}

# ── 顯示逐行 diff ─────────────────────────────────────────────────────────────
diff_content() {
  local old_dir="$1"
  local new_dir="$2"
  local file_filter="$3"

  local files_shown=0

  while IFS= read -r new_f; do
    local rel="${new_f#"$new_dir/"}"
    [[ -n "$file_filter" && "$rel" != *"$file_filter"* ]] && continue

    local old_f="$old_dir/$rel"

    if [[ ! -f "$old_f" ]]; then
      echo ""
      echo -e "${BOLD}${GREEN}+ 新檔案: $rel${RESET}"
      echo -e "${DIM}$(cat "$new_f")${RESET}"
      (( files_shown++ ))
    elif ! cmp -s "$old_f" "$new_f"; then
      echo ""
      echo -e "${BOLD}${YELLOW}~ 變更: $rel${RESET}"
      diff --unified=2 "$old_f" "$new_f" 2>/dev/null \
        | tail -n +3 \
        | while IFS= read -r line; do
            case "${line:0:1}" in
              +) echo -e "${GREEN}${line}${RESET}" ;;
              -) echo -e "${RED}${line}${RESET}" ;;
              @) echo -e "${CYAN}${line}${RESET}" ;;
              *) echo -e "${DIM}${line}${RESET}" ;;
            esac
          done
      (( files_shown++ ))
    fi
  done < <(find "$new_dir" -name "*.md" 2>/dev/null | sort)

  if (( files_shown == 0 )); then
    echo ""
    echo -e "  ${DIM}（沒有變更）${RESET}"
  fi
}

# ── 嘗試用 git 歷史作為「舊版本」 ────────────────────────────────────────────
git_backup_bank() {
  local agent_id="$1"
  local date_filter="$2"
  local tmp_dir="$3"

  cd "$REPO_ROOT"
  if ! git rev-parse --git-dir &>/dev/null; then return 1; fi

  local backup_path="agent-backups/$agent_id/bank"

  # 找符合日期的 commit
  local commit=""
  if [[ -n "$date_filter" ]]; then
    commit=$(git log --format="%H" --before="${date_filter}T23:59:59" \
             --follow -- "$backup_path" 2>/dev/null | head -1)
  else
    # 最早的 commit
    commit=$(git log --format="%H" --follow -- "$backup_path" 2>/dev/null | tail -1)
  fi

  if [[ -z "$commit" ]]; then return 1; fi

  local commit_date
  commit_date=$(git log -1 --format="%ai" "$commit" 2>/dev/null | cut -d' ' -f1)

  # checkout 到臨時目錄
  mkdir -p "$tmp_dir"
  git checkout "$commit" -- "$backup_path" 2>/dev/null || return 1
  cp -r "$REPO_ROOT/$backup_path" "$tmp_dir/bank" 2>/dev/null || true
  git checkout HEAD -- "$backup_path" 2>/dev/null || true  # 還原

  echo "$commit_date"
}

# ── 主程式 ───────────────────────────────────────────────────────────────────
echo -e "${BOLD}Bank Knowledge Diff${RESET}"
echo -e "${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"

# 取得現在的 bank/
current_bank=$(resolve_workspace_bank)
if [[ -z "$current_bank" || ! -d "$current_bank" ]]; then
  echo ""
  echo "❌ 找不到現在的 bank/ 目錄。"
  echo "   使用 --workspace 指定路徑，或先執行 ./scripts/init-agent-growth.sh"
  exit 1
fi

# 解析 agent ID（從路徑猜）
if [[ -z "$AGENT_ID" ]]; then
  if [[ "$current_bank" == *"/agents/"* ]]; then
    AGENT_ID=$(echo "$current_bank" | sed 's|.*/agents/\([^/]*\)/.*|\1|')
  fi
fi

echo ""
echo -e "  現在的 bank/:  ${DIM}$current_bank${RESET}"

# 嘗試從 git 取舊版本
tmp_dir=$(mktemp -d)
trap "rm -rf $tmp_dir" EXIT

old_date=""
old_bank=""

if [[ -n "$AGENT_ID" ]]; then
  old_date=$(git_backup_bank "$AGENT_ID" "$BACKUP_DATE" "$tmp_dir" 2>/dev/null || echo "")
  if [[ -n "$old_date" && -d "$tmp_dir/bank" ]]; then
    old_bank="$tmp_dir/bank"
    echo -e "  舊版 bank/:    ${DIM}git 歷史 ($old_date)${RESET}"
  fi
fi

# fallback：用 agent-backups/ 目錄
if [[ -z "$old_bank" ]]; then
  old_bank=$(resolve_backup_bank "$AGENT_ID")
  if [[ -n "$old_bank" && -d "$old_bank" ]]; then
    echo -e "  舊版 bank/:    ${DIM}$old_bank${RESET}"
  fi
fi

if [[ -z "$old_bank" || ! -d "$old_bank" ]]; then
  echo ""
  echo -e "${YELLOW}⚠️  找不到舊版 bank/ 做比較。${RESET}"
  echo "   先執行備份：./scripts/backup-agent-cores.sh --push"
  echo ""
  echo -e "  ${BOLD}現在的 bank/ 內容：${RESET}"
  find "$current_bank" -name "*.md" | while read -r f; do
    local lines
    lines=$(wc -l < "$f" 2>/dev/null || echo 0)
    echo -e "  ${DIM}$(basename "$f")${RESET}  ${lines} 行"
  done
  exit 0
fi

echo ""

# 顯示統計
diff_stat "$old_bank" "$current_bank" "$FILTER_FILE"

# 顯示逐行 diff（若非 --stat 模式）
if ! $STAT_ONLY; then
  echo -e "${BOLD}── 逐行變更 ──${RESET}"
  diff_content "$old_bank" "$current_bank" "$FILTER_FILE"
fi

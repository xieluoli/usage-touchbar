#!/bin/bash
# ============================================================
# Touch Bar 用量显示脚本（MacBook Pro 端）
# 部署位置: ~/.claude/touchbar-fetch.sh
#
# 数据获取 + 主题调度。渲染逻辑在 themes/ 目录下。
# 切换主题：echo "主题名" > ~/.claude/touchbar-theme
#
# 传输策略：SSH 直连优先（局域网实时），iCloud Drive 兜底（远程）
# ============================================================

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/claude-usage"
ICLOUD_FILE="$ICLOUD_DIR/state.json"
STATE_FILE="${STATE_FILE:-$ICLOUD_FILE}"
THEMES_DIR="${TOUCHBAR_THEMES_DIR:-$HOME/.claude/touchbar-themes}"
THEME_CONF="${TOUCHBAR_THEME_CONF:-$HOME/.claude/touchbar-theme}"

# SSH 配置
SSH_HOST="${TOUCHBAR_SSH_HOST:-xieluoli@100.78.198.51}"
SSH_CMD="/usr/bin/ssh -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
REMOTE_FILE='$HOME/Library/Mobile Documents/com~apple~CloudDocs/claude-usage/state.json'

CACHE_DIR="/tmp/claude-touchbar"
CACHE_FILE="$CACHE_DIR/state.json"
mkdir -p "$CACHE_DIR"

# ===================== 数据获取（SSH 优先 → 本地缓存 → iCloud 兜底） =====================

TRANSPORT="unknown"
RAW=""

# 1) 尝试 SSH 直连
if RAW=$($SSH_CMD $SSH_HOST "cat \"$REMOTE_FILE\"" 2>/dev/null) && [ -n "$RAW" ]; then
  TRANSPORT="ssh"
  echo "$RAW" > "$CACHE_FILE"
# 2) SSH 失败，上次有缓存？（1小时内有效）
elif [ -f "$CACHE_FILE" ] && [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0))) -lt 3600 ]; then
  TRANSPORT="cache"
  RAW=$(cat "$CACHE_FILE")
# 3) iCloud Drive 兜底
elif [ -f "$ICLOUD_FILE" ]; then
  TRANSPORT="icloud"
  RAW=$(cat "$ICLOUD_FILE")
else
  echo "\033[90m⏳ 等待 Mac Mini 数据...\033[0m"
  exit 0
fi

# 解析 JSON
DATA=$(echo "$RAW" | jq -r '
  [
    (.rate_limits.five_hour.used_percentage // "null"),
    (.rate_limits.five_hour.resets_at // "null"),
    (.rate_limits.seven_day.used_percentage // "null"),
    (.rate_limits.seven_day.resets_at // "null"),
    (.rate_limits["7d_sonnet"].used_percentage // "null"),
    (.rate_limits["7d_sonnet"].resets_at // "null"),
    (.last_updated // "null")
  ] | join("|")
' 2>/dev/null || echo "null|null|null|null|null|null|null")

IFS='|' read -r FIVE_PCT FIVE_RESET SEVEN_PCT SEVEN_RESET SONNET_PCT SONNET_RESET UPDATED <<< "$DATA"

# 无数据分支（文件首次创建前）
if [ "$FIVE_PCT" = "null" ] && [ "$SEVEN_PCT" = "null" ]; then
  echo "\033[90m⏳ 等待首次 API 数据...\033[0m"
  exit 0
fi

# ===================== 主题调度 =====================

THEME="hud"
[ -f "$THEME_CONF" ] && THEME=$(head -1 "$THEME_CONF" | tr -d '[:space:]')

THEME_FILE="$THEMES_DIR/${THEME}.sh"

if [ ! -f "$THEME_FILE" ]; then
  echo "\033[90m⚠ 主题 '$THEME' 不存在\033[0m"
  exit 0
fi

# 导出变量供主题使用
export FIVE_PCT FIVE_RESET SEVEN_PCT SEVEN_RESET SONNET_PCT SONNET_RESET UPDATED
export TRANSPORT

source "$THEME_FILE"
render

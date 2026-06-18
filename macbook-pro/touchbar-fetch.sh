#!/bin/bash
# ============================================================
# Touch Bar 用量显示脚本（MacBook Pro 端）
# 部署位置: ~/.claude/touchbar-fetch.sh
#
# 数据获取 + 主题调度。渲染逻辑在 themes/ 目录下。
# 切换主题：echo "主题名" > ~/.claude/touchbar-theme
# ============================================================

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/claude-usage"
STATE_FILE="${STATE_FILE:-$ICLOUD_DIR/state.json}"
THEMES_DIR="${TOUCHBAR_THEMES_DIR:-$HOME/.claude/touchbar-themes}"
THEME_CONF="${TOUCHBAR_THEME_CONF:-$HOME/.claude/touchbar-theme}"

# ===================== 数据获取 =====================

if [ ! -f "$STATE_FILE" ]; then
  echo "\033[90m⏳ 等待 Mac Mini 数据...\033[0m"
  exit 0
fi

DATA=$(jq -r '
  [
    (.rate_limits.five_hour.used_percentage // "null"),
    (.rate_limits.five_hour.resets_at // "null"),
    (.rate_limits.seven_day.used_percentage // "null"),
    (.rate_limits.seven_day.resets_at // "null"),
    (.rate_limits["7d_sonnet"].used_percentage // "null"),
    (.rate_limits["7d_sonnet"].resets_at // "null"),
    (.last_updated // "null")
  ] | join("|")
' "$STATE_FILE" 2>/dev/null || echo "null|null|null|null|null|null|null")

IFS='|' read -r FIVE_PCT FIVE_RESET SEVEN_PCT SEVEN_RESET SONNET_PCT SONNET_RESET UPDATED <<< "$DATA"

# 无数据分支
if [ "$FIVE_PCT" = "null" ] && [ "$SEVEN_PCT" = "null" ]; then
  now=$(date +%s)
  if [ "$UPDATED" != "null" ] && [ $(( now - UPDATED )) -gt 1800 ]; then
    echo "\033[90m⚠  Mac Mini 离线 ($(( (now - UPDATED) / 60 ))分钟前)\033[0m"
  else
    echo "\033[90m⏳ 暂无用量数据\033[0m"
  fi
  exit 0
fi

# ===================== 主题调度 =====================

THEME="hud"  # 默认主题
[ -f "$THEME_CONF" ] && THEME=$(head -1 "$THEME_CONF" | tr -d '[:space:]')

THEME_FILE="$THEMES_DIR/${THEME}.sh"

if [ ! -f "$THEME_FILE" ]; then
  echo "\033[90m⚠ 主题 '$THEME' 不存在\033[0m"
  exit 0
fi

# 导出变量供主题使用
export FIVE_PCT FIVE_RESET SEVEN_PCT SEVEN_RESET SONNET_PCT SONNET_RESET UPDATED

source "$THEME_FILE"
render

# render 函数由主题文件定义，输出一行 ANSI 格式文本

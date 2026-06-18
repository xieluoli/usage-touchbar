#!/bin/bash
# ============================================================
# Touch Bar 用量显示脚本（MacBook Pro 端）
# 部署位置: ~/.claude/touchbar-fetch.sh
#
# 由 MTMR 每 3 秒调用一次，从 iCloud Drive 读取 Mac Mini
# 写入的用量数据，格式化为彩色进度条输出到 Touch Bar。
# ============================================================

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/claude-usage"
STATE_FILE="$ICLOUD_DIR/state.json"

# ---- 辅助函数 ----

# 根据百分比返回 ANSI 颜色码
color_for() {
  local pct=$1
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    echo "\033[37m"  # 白色 = 未知
  elif [ "${pct%.*}" -ge 80 ]; then
    echo "\033[31m"  # 红色
  elif [ "${pct%.*}" -ge 50 ]; then
    echo "\033[33m"  # 黄色
  else
    echo "\033[32m"  # 绿色
  fi
}

# 绘制 10 格进度条
# 参数: percentage (0-100)
draw_bar() {
  local pct=$1
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    echo "░░░░░░░░░░"
    return
  fi
  local filled=$(( ${pct%.*} / 10 ))
  [ "$filled" -gt 10 ] && filled=10
  local empty=$(( 10 - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty;  i++)); do bar+="░"; done
  echo "$bar"
}

# 计算剩余时间（传入 ISO 8601 时间戳）
# 输出: "3h25m" / "2d4h" / "已重置" / ""
countdown() {
  local reset_at=$1
  if [ -z "$reset_at" ] || [ "$reset_at" = "null" ]; then
    echo ""
    return
  fi

  local now reset_ts
  now=$(date +%s)

  # 尝试解析 ISO 8601 格式（如 "2026-06-18T14:30:00Z"）
  if command -v gdate &>/dev/null; then
    reset_ts=$(gdate -d "$reset_at" +%s 2>/dev/null) || reset_ts=""
  else
    reset_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$reset_at" +%s 2>/dev/null) || reset_ts=""
  fi

  if [ -z "$reset_ts" ]; then
    echo ""
    return
  fi

  local remaining=$(( reset_ts - now ))
  if [ "$remaining" -le 0 ]; then
    echo "✓"
    return
  fi

  local days=$(( remaining / 86400 ))
  local hours=$(( (remaining % 86400) / 3600 ))
  local mins=$(( (remaining % 3600) / 60 ))

  if [ "$days" -gt 0 ]; then
    echo "${days}d${hours}h"
  elif [ "$hours" -gt 0 ]; then
    echo "${hours}h${mins}m"
  else
    echo "${mins}m"
  fi
}

# ---- 主逻辑 ----

# 文件不存在 = Mac Mini 还没写入过数据
if [ ! -f "$STATE_FILE" ]; then
  echo "\033[90m⏳ 等待 Mac Mini 数据...\033[0m"
  exit 0
fi

# 用 jq 一次性解析所有字段
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

# 全部为 null = rate_limits 还没出现
if [ "$FIVE_PCT" = "null" ] && [ "$SEVEN_PCT" = "null" ]; then
  # 检查数据是否过期（超过 30 分钟无更新视为断连）
  now=$(date +%s)
  if [ "$UPDATED" != "null" ] && [ $(( now - UPDATED )) -gt 1800 ]; then
    echo "\033[90m⚠  Mac Mini 离线 ($(( (now - UPDATED) / 60 ))分钟前)\033[0m"
  else
    echo "\033[90m⏳ 暂无用量数据\033[0m"
  fi
  exit 0
fi

# ---- 渲染 Touch Bar 输出 ----

# 5h 窗口
COLOR_5H=$(color_for "$FIVE_PCT")
BAR_5H=$(draw_bar "$FIVE_PCT")
CD_5H=$(countdown "$FIVE_RESET")
PCT_5H="${FIVE_PCT:-?}"

# 7d 窗口
COLOR_7D=$(color_for "$SEVEN_PCT")
BAR_7D=$(draw_bar "$SEVEN_PCT")
CD_7D=$(countdown "$SEVEN_RESET")
PCT_7D="${SEVEN_PCT:-?}"

# 输出格式: [5h: 进度条 百分比 倒计时]  [7d: 进度条 百分比 倒计时]  [状态]
printf "${COLOR_5H}5h %s %3s%%" "$BAR_5H" "$PCT_5H"
[ -n "$CD_5H" ] && printf " ↺%s" "$CD_5H"

printf "  ${COLOR_7D}7d %s %3s%%" "$BAR_7D" "$PCT_7D"
[ -n "$CD_7D" ] && printf " ↺%s" "$CD_7D"

# 数据新鲜度指示
now=$(date +%s)
if [ "$UPDATED" != "null" ]; then
  age=$(( now - UPDATED ))
  if [ "$age" -lt 60 ]; then
    printf "  \033[32m●\033[0m"
  elif [ "$age" -lt 300 ]; then
    printf "  \033[33m●\033[0m"
  else
    printf "  \033[90m●\033[0m"
  fi
fi

echo ""

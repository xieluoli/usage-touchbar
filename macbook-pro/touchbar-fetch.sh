#!/bin/bash
# ============================================================
# Touch Bar 用量显示脚本（MacBook Pro 端）
# 部署位置: ~/.claude/touchbar-fetch.sh
#
# 由 MTMR 每 3 秒调用一次，从 iCloud Drive 读取 Mac Mini
# 写入的用量数据，格式化为 HUD 风格进度条输出到 Touch Bar。
# ============================================================

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/claude-usage"
STATE_FILE="${STATE_FILE:-$ICLOUD_DIR/state.json}"

# ---- 辅助函数 ----

# 1/8 Unicode block 字符: 0→8 = ▏▎▍▌▋▊▉█
BLOCKS=("·" "▏" "▎" "▍" "▌" "▋" "▊" "▉" "█")

# 80 级丝滑进度条（10 主格 × 8 子级 = 80 步 ≈ 1.25%/步）
# 渐变色：青 → 亮白 → 黄 → 红（HUD 温度计风格）
draw_bar() {
  local pct=$1
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    echo "\033[90m━━━━━━━━━━\033[0m"
    return
  fi

  local pct_int=${pct%.*}
  local steps=$(( pct_int * 80 / 100 ))
  [ "$steps" -gt 80 ] && steps=80

  local bar=""
  for ((i=0; i<10; i++)); do
    local block_pos=$(( i * 8 ))
    local sub=$(( steps - block_pos ))

    local char
    if [ $sub -ge 8 ]; then char=8
    elif [ $sub -le 0 ]; then char=0
    else char=$sub
    fi

    # 渐变色：根据块位置决定颜色
    if [ $i -le 2 ]; then
      bar+="\033[36m${BLOCKS[$char]}"
    elif [ $i -le 4 ]; then
      bar+="\033[1;37m${BLOCKS[$char]}"
    elif [ $i -le 6 ]; then
      bar+="\033[33m${BLOCKS[$char]}"
    elif [ $i -le 8 ]; then
      bar+="\033[1;31m${BLOCKS[$char]}"
    else
      bar+="\033[1;35m${BLOCKS[$char]}"
    fi
  done
  bar+="\033[0m"
  echo "$bar"
}

# 紧凑倒计时
countdown() {
  local reset_at=$1
  if [ -z "$reset_at" ] || [ "$reset_at" = "null" ]; then
    echo ""
    return
  fi

  local now reset_ts
  now=$(date +%s)

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
    echo "✧"
    return
  fi

  local days=$(( remaining / 86400 ))
  local hours=$(( (remaining % 86400) / 3600 ))
  local mins=$(( (remaining % 3600) / 60 ))

  if [ "$days" -gt 0 ]; then
    printf "%dd%dh" "$days" "$hours"
  elif [ "$hours" -gt 0 ]; then
    printf "%dh%dm" "$hours" "$mins"
  else
    printf "%dm" "$mins"
  fi
}

# ---- 主逻辑 ----

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

if [ "$FIVE_PCT" = "null" ] && [ "$SEVEN_PCT" = "null" ]; then
  now=$(date +%s)
  if [ "$UPDATED" != "null" ] && [ $(( now - UPDATED )) -gt 1800 ]; then
    echo "\033[90m⚠  Mac Mini 离线 ($(( (now - UPDATED) / 60 ))分钟前)\033[0m"
  else
    echo "\033[90m⏳ 暂无用量数据\033[0m"
  fi
  exit 0
fi

# ---- 渲染 ----

BAR_5H=$(draw_bar "$FIVE_PCT")
CD_5H=$(countdown "$FIVE_RESET")

BAR_7D=$(draw_bar "$SEVEN_PCT")
CD_7D=$(countdown "$SEVEN_RESET")

# 格式化为整数百分比（右对齐 3 位）
fmt_pct() {
  local v=$1
  if [ -z "$v" ] || [ "$v" = "null" ]; then echo "  ?"; return; fi
  printf "%3d" "${v%.*}"
}

# 连线指示灯
now=$(date +%s)
if [ "$UPDATED" != "null" ]; then
  age=$(( now - UPDATED ))
  if [ "$age" -lt 60 ]; then
    DOT="\033[1;32m●\033[0m"
  elif [ "$age" -lt 300 ]; then
    DOT="\033[1;33m●\033[0m"
  else
    DOT="\033[90m●\033[0m"
  fi
else
  DOT="\033[90m○\033[0m"
fi

# HUD 风格渲染
printf "\033[1;36m5H\033[0m %b \033[1m%s%%\033[0m" "$BAR_5H" "$(fmt_pct "$FIVE_PCT")"
[ -n "$CD_5H" ] && printf " \033[90m↺%s\033[0m" "$CD_5H"

printf "  \033[90m┃\033[0m  "

printf "\033[1;36m7D\033[0m %b \033[1m%s%%\033[0m" "$BAR_7D" "$(fmt_pct "$SEVEN_PCT")"
[ -n "$CD_7D" ] && printf " \033[90m↺%s\033[0m" "$CD_7D"

printf "  %b" "$DOT"

echo ""

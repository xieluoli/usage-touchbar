# ============================================================
# 主题: hud（默认）— 渐变温度计进度条
# 80级丝滑，青→亮白→黄→红→亮紫
# ============================================================

BLOCKS=("·" "▏" "▎" "▍" "▌" "▋" "▊" "▉" "█")

draw_bar() {
  local pct=$1
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    echo "\033[90m━━━━━━━━━━\033[0m"
    return
  fi
  local steps=$(( ${pct%.*} * 80 / 100 ))
  [ "$steps" -gt 80 ] && steps=80

  local bar=""
  for ((i=0; i<10; i++)); do
    local sub=$(( steps - i * 8 ))
    local char
    if [ $sub -ge 8 ]; then char=8
    elif [ $sub -le 0 ]; then char=0
    else char=$sub
    fi
    if   [ $i -le 2 ]; then bar+="\033[36m${BLOCKS[$char]}"
    elif [ $i -le 4 ]; then bar+="\033[1;37m${BLOCKS[$char]}"
    elif [ $i -le 6 ]; then bar+="\033[33m${BLOCKS[$char]}"
    elif [ $i -le 8 ]; then bar+="\033[1;31m${BLOCKS[$char]}"
    else                    bar+="\033[1;35m${BLOCKS[$char]}"
    fi
  done
  bar+="\033[0m"
  echo "$bar"
}

countdown() {
  local ts=$1
  [ -z "$ts" ] || [ "$ts" = "null" ] && { echo ""; return; }
  local rst base
  # 兼容两种格式：Unix 时间戳整数 / ISO 8601 字符串（Z 或 +00:00）
  if [[ "$ts" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    rst=${ts%.*}
  else
    base="${ts%Z}"; base="${base%+*}"  # 剥离时区后缀
    rst=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$base" +%s 2>/dev/null) || rst=""
  fi
  [ -z "$rst" ] && { echo ""; return; }
  local r=$(( rst - $(date +%s) ))
  [ "$r" -le 0 ] && { echo "✧"; return; }
  local d=$(( r/86400 )) h=$(( (r%86400)/3600 )) m=$(( (r%3600)/60 ))
  [ "$d" -gt 0 ] && printf "%dd%dh" "$d" "$h" || { [ "$h" -gt 0 ] && printf "%dh%dm" "$h" "$m" || printf "%dm" "$m"; }
}

fmt_pct() {
  local v=$1
  [ -z "$v" ] || [ "$v" = "null" ] && { echo "  ?"; return; }
  printf "%3d" "${v%.*}"
}

dot() {
  [ "$UPDATED" = "null" ] && { echo "\033[90m○\033[0m"; return; }
  local age=$(( $(date +%s) - UPDATED ))
  if   [ "$age" -lt 60  ]; then echo "\033[1;32m●\033[0m"
  elif [ "$age" -lt 300 ]; then echo "\033[1;33m●\033[0m"
  else                          echo "\033[90m●\033[0m"
  fi
}

render() {
  local bar5 cd5 bar7 cd7 d
  bar5=$(draw_bar "$FIVE_PCT");  cd5=$(countdown "$FIVE_RESET")
  bar7=$(draw_bar "$SEVEN_PCT"); cd7=$(countdown "$SEVEN_RESET")
  d=$(dot)

  printf "\033[1;36m5H\033[0m %b \033[1m%s%%\033[0m" "$bar5" "$(fmt_pct "$FIVE_PCT")"
  [ -n "$cd5" ] && printf " \033[90m↺%s\033[0m" "$cd5"
  printf "  \033[90m┃\033[0m  "
  printf "\033[1;36m7D\033[0m %b \033[1m%s%%\033[0m" "$bar7" "$(fmt_pct "$SEVEN_PCT")"
  [ -n "$cd7" ] && printf " \033[90m↺%s\033[0m" "$cd7"
  printf "  %b\n" "$d"
}

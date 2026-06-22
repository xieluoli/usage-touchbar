# ============================================================
# 主题: neon — 赛博朋克霓虹灯
# 品红/青色双色，方括号框体，闪烁脉冲指示
# ============================================================

FILL=("·" "▏" "▎" "▍" "▌" "▋" "▊" "▉" "█")

draw_bar() {
  local pct=$1 color=$2
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    echo "\033[90m[··········]\033[0m"
    return
  fi
  local steps=$(( ${pct%.*} * 80 / 100 ))
  [ "$steps" -gt 80 ] && steps=80

  local bar="$color["
  for ((i=0; i<10; i++)); do
    local sub=$(( steps - i * 8 ))
    local char
    if [ $sub -ge 8 ]; then char=8
    elif [ $sub -le 0 ]; then char=0
    else char=$sub
    fi
    bar+="${FILL[$char]}"
  done
  bar+="]\033[0m"
  echo "$bar"
}

countdown() {
  local ts=$1
  [ -z "$ts" ] || [ "$ts" = "null" ] && { echo ""; return; }
  local rst base
  if [[ "$ts" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    rst=${ts%.*}
  else
    base="${ts%Z}"; base="${base%+*}"
    rst=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$base" +%s 2>/dev/null) || rst=""
  fi
  [ -z "$rst" ] && { echo ""; return; }
  local r=$(( rst - $(date +%s) ))
  [ "$r" -le 0 ] && { echo ""; return; }
  local d=$(( r/86400 )) h=$(( (r%86400)/3600 )) m=$(( (r%3600)/60 ))
  printf "\033[90m"
  [ "$d" -gt 0 ] && printf "%dd%dh" "$d" "$h" || { [ "$h" -gt 0 ] && printf "%dh%dm" "$h" "$m" || printf "%dm" "$m"; }
  printf "\033[0m"
}

fmt_pct() {
  local v=$1
  [ -z "$v" ] || [ "$v" = "null" ] && { echo "  ?"; return; }
  printf "%3d" "${v%.*}"
}

# 脉冲点：用奇数秒交替显隐模拟呼吸
pulse() {
  local active=$1 color=$2
  if [ $(( $(date +%s) % 2 )) -eq 0 ]; then
    echo "${color}◉\033[0m"
  else
    echo "${color}◎\033[0m"
  fi
}

render() {
  local bar5 cd5 bar7 cd7

  bar5=$(draw_bar "$FIVE_PCT" "\033[1;35m")    # 品红
  cd5=$(countdown "$FIVE_RESET")
  bar7=$(draw_bar "$SEVEN_PCT" "\033[1;36m")   # 青色
  cd7=$(countdown "$SEVEN_RESET")

  # 连线：30秒内=在线
  local online="\033[90m⟡\033[0m"
  [ "$UPDATED" != "null" ] && [ $(( $(date +%s) - UPDATED )) -lt 30 ] && \
    online=$(pulse "5H" "\033[1;35m")

  printf "\033[1;35m◈ 5H\033[0m %b \033[1m%s%%\033[0m" "$bar5" "$(fmt_pct "$FIVE_PCT")"
  [ -n "$cd5" ] && printf " %b" "$cd5"
  printf "  "
  printf "\033[1;36m◈ 7D\033[0m %b \033[1m%s%%\033[0m" "$bar7" "$(fmt_pct "$SEVEN_PCT")"
  [ -n "$cd7" ] && printf " %b" "$cd7"
  printf " %b\n" "$online"
}

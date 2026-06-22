# ============================================================
# 主题: hud（默认）— 渐变温度计进度条
# 全宽 █/░ block，16 色 ANSI，Touch Bar 原生友好
# ============================================================

draw_bar() {
  local pct=$1
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    echo "\033[90m░░░░░░░░░░\033[0m"
    return
  fi
  local pct_int=${pct%.*}
  [ "$pct_int" -gt 100 ] && pct_int=100
  local filled=$(( pct_int / 10 ))
  local partial=$(( pct_int % 10 ))
  [ "$partial" -gt 0 ] && filled=$(( filled + 1 ))
  [ "$filled" -gt 10 ] && filled=10

  local bar=""
  for ((i=0; i<10; i++)); do
    if [ $i -ge $filled ]; then
      bar+="\033[90m░"
    elif [ $i -le 2 ]; then
      bar+="\033[36m█"
    elif [ $i -le 4 ]; then
      bar+="\033[1;37m█"
    elif [ $i -le 6 ]; then
      bar+="\033[33m█"
    elif [ $i -le 8 ]; then
      bar+="\033[1;31m█"
    else
      bar+="\033[1;35m█"
    fi
  done
  bar+="\033[0m"
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

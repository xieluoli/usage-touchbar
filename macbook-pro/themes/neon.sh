# ============================================================
# 主题: neon — 赛博朋克霓虹灯
# 方括号框体，脉冲指示，16色 ANSI
# ============================================================

draw_bar() {
  local pct=$1 color=$2
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    echo "\033[90m[░░░░░░░░░░]\033[0m"
    return
  fi
  local pct_int=${pct%.*}
  [ "$pct_int" -gt 100 ] && pct_int=100
  local filled=$(( pct_int / 10 ))
  local partial=$(( pct_int % 10 ))
  [ "$partial" -gt 0 ] && filled=$(( filled + 1 ))
  [ "$filled" -gt 10 ] && filled=10

  local bar="${color}["
  for ((i=0; i<10; i++)); do
    if [ $i -lt $filled ]; then bar+="${color}█"
    else bar+="\033[90m░"; fi
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

pulse() {
  if [ $(( $(date +%s) % 2 )) -eq 0 ]; then
    echo "\033[1;35m◉\033[0m"
  else
    echo "\033[1;35m◎\033[0m"
  fi
}

render() {
  local bar5 cd5 bar7 cd7
  bar5=$(draw_bar "$FIVE_PCT" "\033[1;35m")
  cd5=$(countdown "$FIVE_RESET")
  bar7=$(draw_bar "$SEVEN_PCT" "\033[1;36m")
  cd7=$(countdown "$SEVEN_RESET")

  local online="\033[90m⟡\033[0m"
  [ "$UPDATED" != "null" ] && [ $(( $(date +%s) - UPDATED )) -lt 30 ] && online=$(pulse)

  printf "\033[1;35m◈ 5H\033[0m %b \033[1m%s%%\033[0m" "$bar5" "$(fmt_pct "$FIVE_PCT")"
  [ -n "$cd5" ] && printf " %b" "$cd5"
  printf "  "
  printf "\033[1;36m◈ 7D\033[0m %b \033[1m%s%%\033[0m" "$bar7" "$(fmt_pct "$SEVEN_PCT")"
  [ -n "$cd7" ] && printf " %b" "$cd7"
  printf " %b\n" "$online"
}

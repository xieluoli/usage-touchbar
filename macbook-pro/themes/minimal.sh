# ============================================================
# 主题: minimal — 极简线条
# 细线进度条，单色百分比，无装饰
# ============================================================

BAR_CHARS=("·" "▏" "▎" "▍" "▌" "▋" "▊" "▉" "█")

draw_bar() {
  local pct=$1
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    echo "──────────"
    return
  fi
  local steps=$(( ${pct%.*} * 10 / 100 ))
  [ "$steps" -gt 10 ] && steps=10
  local bar=""
  for ((i=0; i<steps; i++)); do bar+="━"; done
  for ((i=steps; i<10; i++)); do bar+="─"; done
  echo "$bar"
}

pct_color() {
  local pct=$1
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    echo "\033[90m"
  elif [ "${pct%.*}" -ge 80 ]; then
    echo "\033[31m"
  elif [ "${pct%.*}" -ge 50 ]; then
    echo "\033[33m"
  else
    echo "\033[32m"
  fi
}

countdown() {
  local ts=$1
  [ -z "$ts" ] || [ "$ts" = "null" ] && { echo ""; return; }
  local rst
  rst=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null) || rst=""
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
  [ -z "$v" ] || [ "$v" = "null" ] && { echo " ?"; return; }
  printf "%2d" "${v%.*}"
}

render() {
  local c5 bar5 cd5 c7 bar7 cd7

  c5=$(pct_color "$FIVE_PCT")
  bar5=$(draw_bar "$FIVE_PCT")
  cd5=$(countdown "$FIVE_RESET")

  c7=$(pct_color "$SEVEN_PCT")
  bar7=$(draw_bar "$SEVEN_PCT")
  cd7=$(countdown "$SEVEN_RESET")

  printf "5h %b%b\033[0m %b%s%%\033[0m" "$bar5" "$c5" "$c5" "$(fmt_pct "$FIVE_PCT")"
  [ -n "$cd5" ] && printf " %b" "$cd5"

  printf " · "

  printf "7d %b%b\033[0m %b%s%%\033[0m" "$bar7" "$c7" "$c7" "$(fmt_pct "$SEVEN_PCT")"
  [ -n "$cd7" ] && printf " %b" "$cd7"

  echo ""
}

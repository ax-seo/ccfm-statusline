#!/bin/bash
# CCFM Statusline v1.2 (macOS + Windows Git Bash 호환)

input=$(cat)

# Colors
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
WHITE='\033[97m'
RESET='\033[0m'
BOLD='\033[1m'
MAGENTA='\033[35m'

# JSON 파싱
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "~"')
PROJECT=$(basename "$DIR")
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
CTX_USED=$(echo "$input" | jq -r '(.context_window.used_percentage // 0) * (.context_window.context_window_size // 200000) / 100' | cut -d. -f1)

FIVE_H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0' | cut -d. -f1)
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // 0')
SEVEN_D_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0' | cut -d. -f1)
SEVEN_D_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // 0')

format_tokens() {
  local tokens=$1
  if [ "$tokens" -ge 1000 ]; then
    echo "$((tokens / 1000))k"
  else
    echo "$tokens"
  fi
}

CTX_USED_FMT=$(format_tokens "$CTX_USED")
CTX_SIZE_FMT=$(format_tokens "$CTX_SIZE")

format_reset() {
  local reset_epoch=$1
  if [ "$reset_epoch" = "0" ] || [ "$reset_epoch" = "null" ]; then
    echo ""; return
  fi
  local now=$(date +%s)
  local diff=$((reset_epoch - now))
  if [ "$diff" -le 0 ]; then
    echo "(now)"; return
  fi
  local hours=$((diff / 3600))
  local mins=$(((diff % 3600) / 60))
  echo "(${hours}h${mins}m)"
}

format_reset_day() {
  local reset_epoch=$1
  if [ "$reset_epoch" = "0" ] || [ "$reset_epoch" = "null" ]; then
    echo ""; return
  fi
  local day
  day=$(date -r "$reset_epoch" +%a 2>/dev/null) || \
  day=$(date -d "@$reset_epoch" +%a 2>/dev/null) || \
  day=""
  if [ -n "$day" ]; then
    echo "($day)"
  else
    echo ""
  fi
}

FIVE_H_RESET_FMT=$(format_reset "$FIVE_H_RESET")
SEVEN_D_RESET_FMT=$(format_reset_day "$SEVEN_D_RESET")

# 현재 시각
NOW_TIME=$(date +%H:%M)
NOW_DATE=$(date +%m/%d)

# Git 브랜치
BRANCH=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
fi

# 터미널 너비
COLS=$(tput cols 2>/dev/null || echo 120)

bar_color() {
  local pct=$1
  if [ "$pct" -ge 90 ]; then
    printf "$RED"
  elif [ "$pct" -ge 70 ]; then
    printf "$YELLOW"
  else
    printf "$GREEN"
  fi
}

draw_bar() {
  local pct=$1
  local width=$2
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  bar_color "$pct"
  local i=0
  while [ $i -lt $filled ]; do printf "█"; i=$((i+1)); done
  printf "${DIM}"
  i=0
  while [ $i -lt $empty ]; do printf "░"; i=$((i+1)); done
  printf "${RESET}"
}

pct_color() {
  local pct=$1
  bar_color "$pct"
  printf "%s%%" "$pct"
  printf "${RESET}"
}

# 우측 정렬 헬퍼
right_align() {
  local text="$1"
  local visible_len="$2"
  local line_used="$3"
  local padding=$((COLS - line_used - visible_len - 1))
  if [ "$padding" -gt 0 ]; then
    printf "%${padding}s" ""
  fi
  printf "%s" "$text"
}

# ── Line 1: 프로젝트 + Git + 시각 ──
LINE1_LEFT=""
if [ -n "$BRANCH" ]; then
  LINE1_LEFT=$(printf " 📂 ${CYAN}${BOLD}%s${RESET} │ ⑂ ${GREEN}%s${RESET}" "$PROJECT" "$BRANCH")
  LINE1_LEFT_LEN=$((4 + ${#PROJECT} + 5 + ${#BRANCH}))
else
  LINE1_LEFT=$(printf " 📂 ${CYAN}${BOLD}%s${RESET}" "$PROJECT")
  LINE1_LEFT_LEN=$((4 + ${#PROJECT}))
fi
LINE1_RIGHT=$(printf "${DIM}%s %s${RESET}" "$NOW_TIME" "$NOW_DATE")
LINE1_RIGHT_LEN=$((${#NOW_TIME} + 1 + ${#NOW_DATE}))

printf "%s" "$LINE1_LEFT"
right_align "$LINE1_RIGHT" "$LINE1_RIGHT_LEN" "$LINE1_LEFT_LEN"
printf "\n"

# ── Line 2: Context 바 ──
printf " ▸ ${WHITE}Context${RESET} "; draw_bar "$CTX_PCT" 20; printf " "; pct_color "$CTX_PCT"; printf " ${DIM}(%s/%s)${RESET}\n" "$CTX_USED_FMT" "$CTX_SIZE_FMT"

# ── Line 3: 5H + 7D rate limit ──
printf " ▸ ${WHITE}5H${RESET} "; draw_bar "$FIVE_H_PCT" 10; printf " "; pct_color "$FIVE_H_PCT"; printf " ${DIM}%s${RESET}  ${WHITE}7D${RESET} " "$FIVE_H_RESET_FMT"; draw_bar "$SEVEN_D_PCT" 10; printf " "; pct_color "$SEVEN_D_PCT"; printf " ${DIM}%s${RESET}\n" "$SEVEN_D_RESET_FMT"

# ── Line 4~5: 캘린더 (캐시 파일 있을 때만) ──
CALENDAR_CACHE=~/.claude/calendar-cache.json
if [ -f "$CALENDAR_CACHE" ]; then
  NOW_EPOCH=$(date +%s)
  EVENTS=$(jq -r --argjson now "$NOW_EPOCH" '
    [.[] | select(.start_epoch > $now)] | sort_by(.start_epoch) | .[0:3] |
    .[] | "\(.time) \(.title) (\(.duration))"
  ' "$CALENDAR_CACHE" 2>/dev/null)

  if [ -n "$EVENTS" ]; then
    printf " ${DIM}──────────────────────────────────────${RESET}\n"
    while IFS= read -r event; do
      printf " ${MAGENTA}📅${RESET} %s\n" "$event"
    done <<< "$EVENTS"
  fi
fi

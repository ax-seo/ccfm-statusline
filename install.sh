#!/bin/bash
# CCFM Statusline Installer v1.0
# 사용법: curl -sL https://raw.githubusercontent.com/ccfm-org/ccfm-statusline/main/install.sh | bash

set -e

# jq 체크
if ! command -v jq &> /dev/null; then
  echo "⚠️  jq가 필요합니다. 설치 중..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install jq
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo apt-get install -y jq
  else
    echo "❌ jq를 수동 설치해주세요: https://jqlang.github.io/jq/download/"
    exit 1
  fi
fi

# .claude 디렉토리 확인
mkdir -p ~/.claude

# statusline.sh 생성
cat > ~/.claude/statusline.sh << 'SCRIPT'
#!/bin/bash
# CCFM Statusline v1.0

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
  local day=$(date -r "$reset_epoch" +%a 2>/dev/null || date -d "@$reset_epoch" +%a 2>/dev/null)
  echo "($day)"
}

FIVE_H_RESET_FMT=$(format_reset "$FIVE_H_RESET")
SEVEN_D_RESET_FMT=$(format_reset_day "$SEVEN_D_RESET")

BRANCH=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
fi

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

if [ -n "$BRANCH" ]; then
  printf " 📂 ${CYAN}${BOLD}%s${RESET} │ ⑂ ${GREEN}%s${RESET}\n" "$PROJECT" "$BRANCH"
else
  printf " 📂 ${CYAN}${BOLD}%s${RESET}\n" "$PROJECT"
fi

printf " ▸ ${WHITE}Context${RESET} "; draw_bar "$CTX_PCT" 20; printf " "; pct_color "$CTX_PCT"; printf " ${DIM}(%s/%s)${RESET}\n" "$CTX_USED_FMT" "$CTX_SIZE_FMT"

printf " ▸ ${WHITE}5H${RESET} "; draw_bar "$FIVE_H_PCT" 10; printf " "; pct_color "$FIVE_H_PCT"; printf " ${DIM}%s${RESET}  ${WHITE}7D${RESET} " "$FIVE_H_RESET_FMT"; draw_bar "$SEVEN_D_PCT" 10; printf " "; pct_color "$SEVEN_D_PCT"; printf " ${DIM}%s${RESET}\n" "$SEVEN_D_RESET_FMT"
SCRIPT

chmod +x ~/.claude/statusline.sh

# settings.json 업데이트
SETTINGS=~/.claude/settings.json
STATUSLINE_CONFIG='{"type":"command","command":"~/.claude/statusline.sh"}'

if [ -f "$SETTINGS" ]; then
  if echo "$SETTINGS" | jq -e '.statusLine' > /dev/null 2>&1; then
    jq --argjson sl "$STATUSLINE_CONFIG" '.statusLine = $sl' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
  else
    jq --argjson sl "$STATUSLINE_CONFIG" '. + {statusLine: $sl}' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
  fi
else
  echo "{\"statusLine\": $STATUSLINE_CONFIG}" | jq '.' > "$SETTINGS"
fi

echo ""
echo "✅ CCFM Statusline 설치 완료!"
echo "   Claude Code를 재시작하면 적용됩니다."
echo ""

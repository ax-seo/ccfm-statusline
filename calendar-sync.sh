#!/bin/bash
# CCFM Calendar Sync - Google Calendar → 캐시 파일
# cron으로 5분마다 실행: */5 * * * * ~/.claude/calendar-sync.sh
#
# 사전 설정 필요:
#   1. Google Cloud Console에서 Calendar API 활성화
#   2. OAuth 2.0 클라이언트 ID 생성 (Desktop app)
#   3. 최초 1회 인증 후 refresh_token 저장
#
# 또는 gcalcli 사용: brew install gcalcli && gcalcli init

CACHE_FILE=~/.claude/calendar-cache.json
CONFIG_FILE=~/.claude/calendar-config.json

# ── 방법 1: gcalcli (권장 — 설정 간편) ──
if command -v gcalcli &> /dev/null; then
  TODAY=$(date +%Y-%m-%d)
  TOMORROW=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d "+1 day" +%Y-%m-%d)

  gcalcli agenda "$TODAY" "$TOMORROW" --tsv 2>/dev/null | \
  awk -F'\t' '{
    start = $1 " " $2
    end = $3 " " $4
    title = $5
    # 시간 포맷
    split($2, t, ":")
    time_str = t[1] ":" t[2]
    print "{\"time\":\"" time_str "\",\"title\":\"" title "\",\"start_epoch\":0,\"duration\":\"\"}"
  }' | jq -s '.' > "$CACHE_FILE.tmp" 2>/dev/null

  if [ -s "$CACHE_FILE.tmp" ]; then
    mv "$CACHE_FILE.tmp" "$CACHE_FILE"
  fi
  exit 0
fi

# ── 방법 2: Google Calendar API 직접 호출 ──
if [ ! -f "$CONFIG_FILE" ]; then
  echo "calendar-config.json이 없습니다. 아래 형식으로 생성하세요:"
  echo '{'
  echo '  "client_id": "YOUR_CLIENT_ID",'
  echo '  "client_secret": "YOUR_CLIENT_SECRET",'
  echo '  "refresh_token": "YOUR_REFRESH_TOKEN"'
  echo '}'
  exit 1
fi

CLIENT_ID=$(jq -r '.client_id' "$CONFIG_FILE")
CLIENT_SECRET=$(jq -r '.client_secret' "$CONFIG_FILE")
REFRESH_TOKEN=$(jq -r '.refresh_token' "$CONFIG_FILE")

# Access token 갱신
ACCESS_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "refresh_token=$REFRESH_TOKEN" \
  -d "grant_type=refresh_token" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  exit 1
fi

# 오늘 일정 가져오기
NOW=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
EOD=$(date -u -v+1d +%Y-%m-%dT00:00:00.000Z 2>/dev/null || date -u -d "+1 day" +%Y-%m-%dT00:00:00.000Z)

curl -s "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=$NOW&timeMax=$EOD&singleEvents=true&orderBy=startTime&maxResults=5" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | \
jq '[.items[] | {
  time: (.start.dateTime // .start.date | split("T")[1] // "" | split("+")[0] | .[0:5]),
  title: .summary,
  start_epoch: (.start.dateTime // .start.date | split("T") | .[0] + "T" + (.[1] // "00:00:00") | split("+")[0] | strptime("%Y-%m-%dT%H:%M:%S") | mktime),
  duration: (
    ((.end.dateTime // .end.date | split("T") | .[0] + "T" + (.[1] // "00:00:00") | split("+")[0] | strptime("%Y-%m-%dT%H:%M:%S") | mktime) -
     (.start.dateTime // .start.date | split("T") | .[0] + "T" + (.[1] // "00:00:00") | split("+")[0] | strptime("%Y-%m-%dT%H:%M:%S") | mktime)) / 60 | floor | tostring + "m"
  )
}]' > "$CACHE_FILE.tmp" 2>/dev/null

if [ -s "$CACHE_FILE.tmp" ]; then
  mv "$CACHE_FILE.tmp" "$CACHE_FILE"
fi

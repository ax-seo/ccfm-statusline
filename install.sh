#!/bin/bash
# CCFM Statusline Installer v1.1 (macOS / Linux)
# 사용법: curl -sL https://raw.githubusercontent.com/ax-seo/ccfm-statusline/main/install.sh | bash

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

# statusline.sh 다운로드
curl -sL https://raw.githubusercontent.com/ax-seo/ccfm-statusline/main/statusline.sh -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh

# settings.json 업데이트
SETTINGS=~/.claude/settings.json
STATUSLINE_CONFIG='{"type":"command","command":"~/.claude/statusline.sh"}'

if [ -f "$SETTINGS" ]; then
  jq --argjson sl "$STATUSLINE_CONFIG" '.statusLine = $sl' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
else
  echo "{\"statusLine\": $STATUSLINE_CONFIG}" | jq '.' > "$SETTINGS"
fi

echo ""
echo "✅ CCFM Statusline 설치 완료!"
echo "   Claude Code를 재시작하면 적용됩니다."
echo ""

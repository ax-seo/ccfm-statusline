# CCFM Statusline Installer v1.1 (Windows PowerShell)
# 사용법: irm https://raw.githubusercontent.com/ax-seo/ccfm-statusline/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

# jq 체크 및 설치
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️  jq가 필요합니다. 설치 중..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id jqlang.jq --accept-source-agreements --accept-package-agreements
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install jq -y
    } else {
        Write-Host "❌ jq를 수동 설치해주세요: https://jqlang.github.io/jq/download/" -ForegroundColor Red
        exit 1
    }
}

# .claude 디렉토리 확인
$claudeDir = Join-Path $env:USERPROFILE ".claude"
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

# statusline.sh 다운로드
$statuslineUrl = "https://raw.githubusercontent.com/ax-seo/ccfm-statusline/main/statusline.sh"
$statuslinePath = Join-Path $claudeDir "statusline.sh"
Invoke-WebRequest -Uri $statuslineUrl -OutFile $statuslinePath -UseBasicParsing

# settings.json 업데이트
$settingsPath = Join-Path $claudeDir "settings.json"
$statusLineConfig = @{ type = "command"; command = "~/.claude/statusline.sh" }

if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $settings | Add-Member -NotePropertyName "statusLine" -NotePropertyValue $statusLineConfig -Force
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
} else {
    @{ statusLine = $statusLineConfig } | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
}

Write-Host ""
Write-Host "✅ CCFM Statusline 설치 완료!" -ForegroundColor Green
Write-Host "   Claude Code를 재시작하면 적용됩니다." -ForegroundColor Gray
Write-Host ""

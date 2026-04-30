# =============================================================
# 진실의 입 - 앱 실행 스크립트
# 백엔드 서버 + Flutter 앱을 동시에 시작합니다.
# =============================================================

$ProjectRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir    = Join-Path $ProjectRoot "backend"
$FlutterDir    = Join-Path $ProjectRoot "the_truth_filtering_engine"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   진실의 입 - 실행 스크립트" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. 연결된 기기 확인 ──────────────────────────
Write-Host "[1/3] 연결된 기기 확인 중..." -ForegroundColor Yellow
$devicesOutput = & flutter devices 2>&1 | Out-String
Write-Host $devicesOutput

# 모바일 기기(android/ios) 존재 여부 확인
$hasMobile = $devicesOutput -match "android|ios"
$hasWindows = $devicesOutput -match "windows"

if ($hasMobile) {
    $runTarget = "flutter run"
    Write-Host "✅ 모바일 기기 감지 → 모바일 앱으로 실행합니다." -ForegroundColor Green
} elseif ($hasWindows) {
    $runTarget = "flutter run -d windows"
    Write-Host "✅ 모바일 기기 없음 → Windows 앱으로 실행합니다." -ForegroundColor Green
} else {
    $runTarget = "flutter run -d chrome --web-port 8080 --web-hostname localhost"
    Write-Host "✅ 모바일/Windows 기기 없음 → 웹(Chrome)으로 실행합니다." -ForegroundColor Yellow
    Write-Host "   URL: http://localhost:8080" -ForegroundColor Yellow
}

Write-Host ""

# ── 2. 백엔드 서버 실행 (새 창) ──────────────────
Write-Host "[2/3] 백엔드 서버 시작 중..." -ForegroundColor Yellow

Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location '$BackendDir'; Write-Host '[백엔드] 서버 시작' -ForegroundColor Cyan; uvicorn main:app --reload --host 0.0.0.0 --port 8000"
) -WindowStyle Normal

Write-Host "✅ 백엔드 서버가 새 창에서 시작됩니다. (http://localhost:8000)" -ForegroundColor Green
Write-Host ""

# ── 3. 백엔드 준비 대기 ──────────────────────────
Write-Host "[3/3] 백엔드 준비 대기 중 (최대 15초)..." -ForegroundColor Yellow
$maxWait = 15
$waited  = 0
$ready   = $false

while ($waited -lt $maxWait) {
    Start-Sleep -Seconds 1
    $waited++
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:8000/" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {}
    Write-Host "  대기 중... ($waited/$maxWait 초)" -ForegroundColor DarkGray
}

if ($ready) {
    Write-Host "✅ 백엔드 준비 완료!" -ForegroundColor Green
} else {
    Write-Host "⚠️  백엔드 응답 없음. 계속 진행합니다." -ForegroundColor Yellow
}

Write-Host ""

# ── 4. Flutter 앱 실행 ───────────────────────────
Write-Host "Flutter 앱 실행: $runTarget" -ForegroundColor Cyan
Write-Host ""

Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location '$FlutterDir'; Write-Host '[Flutter] 앱 시작' -ForegroundColor Cyan; $runTarget"
) -WindowStyle Normal

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   앱이 시작됩니다!" -ForegroundColor Green
Write-Host "   백엔드: http://localhost:8000" -ForegroundColor White

if ($runTarget -match "chrome") {
    Write-Host "   앱: http://localhost:8080" -ForegroundColor White
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "이 창은 닫아도 됩니다." -ForegroundColor DarkGray

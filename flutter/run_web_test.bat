@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PUBSPEC_FILE=%SCRIPT_DIR%pubspec.yaml"
set "BACKEND_ENV_FILE=%SCRIPT_DIR%..\backend\.env"
set "BACKEND_DIR=%SCRIPT_DIR%..\backend"
set "PROJECT_LOG_DIR=%SCRIPT_DIR%..\.codex_logs"

if not exist "%PUBSPEC_FILE%" (
  echo Missing %PUBSPEC_FILE%
  exit /b 1
)

for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$text = Get-Content -Raw -LiteralPath '%PUBSPEC_FILE%'; if ($text -match '(?m)^\s+supabase_url:\s*(.+)$') { $Matches[1].Trim() }"`) do set "SUPABASE_URL=%%A"
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$text = Get-Content -Raw -LiteralPath '%PUBSPEC_FILE%'; if ($text -match '(?m)^\s+supabase_anon_key:\s*(.+)$') { $Matches[1].Trim() }"`) do set "SUPABASE_ANON_KEY=%%A"

if "%SUPABASE_URL%"=="" (
  echo flutter_auth.supabase_url must be set in %PUBSPEC_FILE%
  exit /b 1
)

if "%SUPABASE_ANON_KEY%"=="" (
  echo flutter_auth.supabase_anon_key must be set in %PUBSPEC_FILE%
  exit /b 1
)

if "%BACKEND_BASE_URL%"=="" (
  set "BACKEND_BASE_URL=http://127.0.0.1:8000"
)

if /I "%BACKEND_BASE_URL%"=="http://127.0.0.1:8000" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$portOpen = [bool](Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue); if (-not $portOpen) { New-Item -ItemType Directory -Force -Path '%PROJECT_LOG_DIR%' | Out-Null; Start-Process -FilePath 'python.exe' -ArgumentList @('-m','uvicorn','main:app','--host','127.0.0.1','--port','8000') -WorkingDirectory '%BACKEND_DIR%' -WindowStyle Hidden -RedirectStandardOutput (Join-Path '%PROJECT_LOG_DIR%' 'backend.out.log') -RedirectStandardError (Join-Path '%PROJECT_LOG_DIR%' 'backend.err.log'); Start-Sleep -Seconds 2 }"
)

if "%KAKAO_JS_KEY%"=="" (
  if exist "%BACKEND_ENV_FILE%" (
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$path = '%BACKEND_ENV_FILE%'; $text = Get-Content -Raw -LiteralPath $path; if ($text -match '(?m)^\s*KAKAO_JS_KEY\s*=\s*(.+)$') { $Matches[1].Trim().Trim([char]34).Trim([char]39) }"`) do set "KAKAO_JS_KEY=%%A"
  )
)

set "NAVER_CLIENT_ID=MUUADsIYWROs07ZDyToI"
set "NAVER_CLIENT_SECRET=anh11zkJgj"

cd /d "%SCRIPT_DIR%"

echo Starting Flutter web on http://localhost:8080
call C:\flutter\bin\flutter.bat run -d chrome --web-port 8080 ^
  --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
  --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY% ^
  --dart-define=BACKEND_BASE_URL=%BACKEND_BASE_URL% ^
  --dart-define=KAKAO_JS_KEY=%KAKAO_JS_KEY% ^
  --dart-define=NAVER_CLIENT_ID=%NAVER_CLIENT_ID% ^
  --dart-define=NAVER_CLIENT_SECRET=%NAVER_CLIENT_SECRET%

endlocal

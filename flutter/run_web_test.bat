@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PUBSPEC_FILE=%SCRIPT_DIR%pubspec.yaml"

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

set "NAVER_CLIENT_ID=MUUADsIYWROs07ZDyToI"
set "NAVER_CLIENT_SECRET=anh11zkJgj"

cd /d "%SCRIPT_DIR%"

echo Starting Flutter web on http://localhost:8080
call C:\flutter\bin\flutter.bat run -d chrome --web-port 8080 ^
  --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
  --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY% ^
  --dart-define=BACKEND_BASE_URL=%BACKEND_BASE_URL% ^
  --dart-define=NAVER_CLIENT_ID=%NAVER_CLIENT_ID% ^
  --dart-define=NAVER_CLIENT_SECRET=%NAVER_CLIENT_SECRET%

endlocal

@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PUBSPEC_FILE=%SCRIPT_DIR%pubspec.yaml"

if not exist "%PUBSPEC_FILE%" (
  echo Missing %PUBSPEC_FILE%
  exit /b 1
)

set "IN_FLUTTER_AUTH="
for /f "usebackq tokens=1,* delims=:" %%A in ("%PUBSPEC_FILE%") do (
  if "%%A"=="flutter_auth" set "IN_FLUTTER_AUTH=1"
  if defined IN_FLUTTER_AUTH (
    if "%%A"=="dependencies" set "IN_FLUTTER_AUTH="
    if "%%A"=="  supabase_url" for /f "tokens=* delims= " %%C in ("%%B") do set "SUPABASE_URL=%%C"
    if "%%A"=="  supabase_anon_key" for /f "tokens=* delims= " %%C in ("%%B") do set "SUPABASE_ANON_KEY=%%C"
  )
)

if "%SUPABASE_URL%"=="" (
  echo flutter_auth.supabase_url must be set in %PUBSPEC_FILE%
  exit /b 1
)

if "%SUPABASE_ANON_KEY%"=="" (
  echo flutter_auth.supabase_anon_key must be set in %PUBSPEC_FILE%
  exit /b 1
)

cd /d "%SCRIPT_DIR%"

flutter run -d chrome --web-port 8080 ^
  --dart-define=SUPABASE_URL="%SUPABASE_URL%" ^
  --dart-define=SUPABASE_ANON_KEY="%SUPABASE_ANON_KEY%"

endlocal

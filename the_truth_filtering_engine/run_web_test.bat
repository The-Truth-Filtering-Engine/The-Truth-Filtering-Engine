@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "ENV_FILE=%SCRIPT_DIR%flutter_auth.env"

if not exist "%ENV_FILE%" (
  echo Missing %ENV_FILE%
  echo Create it with:
  echo SUPABASE_URL=https://trhwelbdnhhpldpkrxmp.supabase.co
  echo SUPABASE_ANON_KEY=sb_publishable_z-Ygpb1vyo8-LSxkcqTduw_K_58bqV6
  exit /b 1
)

for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
  if not "%%A"=="" set "%%A=%%B"
)

if "%SUPABASE_URL%"=="" (
  echo SUPABASE_URL must be set in %ENV_FILE%
  exit /b 1
)

if "%SUPABASE_ANON_KEY%"=="" (
  echo SUPABASE_ANON_KEY must be set in %ENV_FILE%
  exit /b 1
)

cd /d "%SCRIPT_DIR%"

flutter run -d chrome --web-port 8080 ^
  --dart-define=SUPABASE_URL="%SUPABASE_URL%" ^
  --dart-define=SUPABASE_ANON_KEY="%SUPABASE_ANON_KEY%"

endlocal

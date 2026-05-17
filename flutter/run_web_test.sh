#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PUBSPEC_FILE="$SCRIPT_DIR/pubspec.yaml"
BACKEND_ENV_FILE="$SCRIPT_DIR/../backend/.env"
BACKEND_DIR="$SCRIPT_DIR/../backend"
PROJECT_LOG_DIR="$SCRIPT_DIR/../.codex_logs"

if [ ! -f "$PUBSPEC_FILE" ]; then
  echo "Missing $PUBSPEC_FILE"
  exit 1
fi

read_pubspec_value() {
  awk -v key="$1" '
    /^flutter_auth:/ { in_auth = 1; next }
    in_auth && /^[^[:space:]]/ { in_auth = 0 }
    in_auth {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      split(line, parts, ":")
      if (parts[1] == key) {
        sub(/^[^:]+:[[:space:]]*/, "", line)
        print line
        exit
      }
    }
  ' "$PUBSPEC_FILE"
}

SUPABASE_URL=$(read_pubspec_value "supabase_url")
SUPABASE_ANON_KEY=$(read_pubspec_value "supabase_anon_key")

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "flutter_auth.supabase_url and flutter_auth.supabase_anon_key must be set in $PUBSPEC_FILE"
  exit 1
fi

cd "$SCRIPT_DIR"

BACKEND_BASE_URL="${BACKEND_BASE_URL:-http://127.0.0.1:8000}"
if [ "$BACKEND_BASE_URL" = "http://127.0.0.1:8000" ]; then
  if ! python - <<'PY' >/dev/null 2>&1
import socket
with socket.create_connection(("127.0.0.1", 8000), timeout=1):
    pass
PY
  then
    mkdir -p "$PROJECT_LOG_DIR"
    (
      cd "$BACKEND_DIR"
      nohup python -m uvicorn main:app --host 127.0.0.1 --port 8000 \
        > "$PROJECT_LOG_DIR/backend.out.log" \
        2> "$PROJECT_LOG_DIR/backend.err.log" &
    )
    sleep 2
  fi
fi

KAKAO_JS_KEY="${KAKAO_JS_KEY:-}"
if [ -z "$KAKAO_JS_KEY" ] && [ -f "$BACKEND_ENV_FILE" ]; then
  KAKAO_JS_KEY=$(
    awk -F= '
      /^[[:space:]]*KAKAO_JS_KEY[[:space:]]*=/ {
        value = $0
        sub(/^[^=]+=[[:space:]]*/, "", value)
        gsub(/^[\"\047]|[\"\047]$/, "", value)
        print value
        exit
      }
    ' "$BACKEND_ENV_FILE"
  )
fi

# ── Naver OAuth ─────────────────────────────────────────────────
NAVER_CLIENT_ID="MUUADsIYWROs07ZDyToI"
NAVER_CLIENT_SECRET="anh11zkJgj"

flutter run -d chrome --web-port 8080 \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=BACKEND_BASE_URL="$BACKEND_BASE_URL" \
  --dart-define=KAKAO_JS_KEY="$KAKAO_JS_KEY" \
  --dart-define=NAVER_CLIENT_ID="$NAVER_CLIENT_ID" \
  --dart-define=NAVER_CLIENT_SECRET="$NAVER_CLIENT_SECRET"

#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PUBSPEC_FILE="$SCRIPT_DIR/pubspec.yaml"

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

flutter run -d chrome --web-port 8080 \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

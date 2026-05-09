#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ENV_FILE="$SCRIPT_DIR/flutter_auth.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE"
  echo "Create it with:"
  echo "SUPABASE_URL=https://trhwelbdnhhpldpkrxmp.supabase.co"
  echo "SUPABASE_ANON_KEY=sb_publishable_z-Ygpb1vyo8-LSxkcqTduw_K_58bqV6"
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "SUPABASE_URL and SUPABASE_ANON_KEY must be set in $ENV_FILE"
  exit 1
fi

cd "$SCRIPT_DIR"

flutter run -d chrome --web-port 8080 \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

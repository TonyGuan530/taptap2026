#!/usr/bin/env bash
# Push a build to itch.io with butler (official CLI).
# Usage:
#   ./tools/push-itch.sh [version]          (uses BUTLER_API_KEY env / saved butler login)
#   BUTLER_API_KEY=xxx ./tools/push-itch.sh v0.0.1-demo
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUILDS="$REPO/builds"
BUTLER="$REPO/tools/butler/butler"
[ -x "$BUTLER" ] || BUTLER="$(command -v butler)"
[ -n "$BUTLER" ] || { echo "butler not found (tools/butler/butler or PATH)"; exit 1; }

TARGET="${ITCH_TARGET:-sxguan/taptap2026}"
CHANNEL="${ITCH_CHANNEL:-html}"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  VERSION="$(ls -1t "$BUILDS" | while read -r d; do
    [ -f "$BUILDS/$d/index.html" ] && echo "$d" && break
  done)"
  [ -n "$VERSION" ] || { echo "No build with index.html found under builds/"; exit 1; }
fi

KEYARGS=()
if [ -n "${BUTLER_API_KEY:-}" ]; then
  KEYFILE="$(mktemp)"
  printf '%s' "$BUTLER_API_KEY" > "$KEYFILE"
  KEYARGS=(-i "$KEYFILE")
fi

echo "Pushing builds/$VERSION -> $TARGET:$CHANNEL ..."
"$BUTLER" push "$BUILDS/$VERSION" "$TARGET:$CHANNEL" --userversion "$VERSION" "${KEYARGS[@]+"${KEYARGS[@]}"}"

USER_NAME="${TARGET%%/*}"
GAME_NAME="${TARGET##*/}"
echo ""
echo "OK: https://$USER_NAME.itch.io/$GAME_NAME"

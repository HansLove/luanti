#!/bin/bash
# Create a Hashimon API session and save the token for Luanti 3D — no 2D game needed.
set -euo pipefail

API_URL="${HASHIMON_API_URL:-http://127.0.0.1:4000}"
STARTER=0
WORLD=""

usage() {
	cat <<EOF
Usage: $(basename "$0") [options] [world-folder]

Creates POST /session and writes hashimon_token.txt into the Luanti world folder.

Options:
  --starter     Also emit a genesis starter Hashimon (once per account)
  --api URL     API base URL (default: $API_URL)
  -h, --help    Show this help

Default world (macOS):
  ~/Library/Application Support/minetest/worlds/Hashimon
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--starter) STARTER=1; shift ;;
		--api) API_URL="$2"; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		-*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
		*) WORLD="$1"; shift ;;
	esac
done

if [[ -z "$WORLD" ]]; then
	if [[ "$(uname)" == "Darwin" ]]; then
		WORLD="$HOME/Library/Application Support/minetest/worlds/Hashimon"
	else
		WORLD="${HOME}/.minetest/worlds/Hashimon"
	fi
fi

if ! command -v curl >/dev/null; then
	echo "curl is required." >&2
	exit 1
fi

if ! command -v jq >/dev/null; then
	echo "jq is required (brew install jq)." >&2
	exit 1
fi

echo "API: $API_URL"
echo "World: $WORLD"

RESP=$(curl -sf -X POST "$API_URL/session" \
	-H 'content-type: application/json' \
	-d '{}' || true)

if [[ -z "$RESP" ]]; then
	echo "Failed to reach API at $API_URL" >&2
	echo "Start it from repo root: cd api && npm run dev" >&2
	exit 1
fi

TOKEN=$(echo "$RESP" | jq -r '.token // empty')
DISPLAY=$(echo "$RESP" | jq -r '.player.displayName // "player"')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
	echo "Invalid session response:" >&2
	echo "$RESP" >&2
	exit 1
fi

mkdir -p "$WORLD"
printf '%s\n' "$TOKEN" > "$WORLD/hashimon_token.txt"
echo "Session OK — $DISPLAY"
echo "Token saved: $WORLD/hashimon_token.txt"

if [[ "$STARTER" -eq 1 ]]; then
	EMIT=$(curl -sf -X POST "$API_URL/hashimons" \
		-H "Authorization: Bearer $TOKEN" \
		-H 'content-type: application/json' \
		-d '{"speciesKey":"s001","provenance":"starter"}' 2>/dev/null || true)
	if echo "$EMIT" | jq -e '.id' >/dev/null 2>&1; then
		NAME=$(echo "$EMIT" | jq -r '.name // "Genesis"')
		echo "Starter emitted: $NAME"
	else
		echo "Starter not emitted (may already exist or API error)."
	fi
fi

echo ""
echo "In Luanti 3D: /hashimon file   or   /hashimon session"

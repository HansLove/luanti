#!/usr/bin/env bash
# PostToolUse hook: lint a just-edited .lua file with luacheck, matching the
# same scope .github/workflows/lua.yml lints (builtin/, games/devtest/).
# mods/hashimon_* is intentionally excluded — it has no wired .luacheckrc.
set -euo pipefail

input="$(cat)"
file_path="$(jq -r '.tool_input.file_path // empty' <<<"$input")"

[[ -z "$file_path" ]] && exit 0
[[ "$file_path" != *.lua ]] && exit 0

repo_root="$(git rev-parse --show-toplevel)"
rel_path="${file_path#"$repo_root"/}"

config=""
case "$rel_path" in
builtin/*)
	config=""
	;;
games/devtest/*)
	config="--config=games/devtest/.luacheckrc"
	;;
*)
	exit 0
	;;
esac

if ! command -v luacheck >/dev/null 2>&1; then
	echo "luacheck not found on PATH; skipped lint for $rel_path" >&2
	exit 0
fi

cd "$repo_root"
if ! luacheck $config "$rel_path" >&2; then
	echo "luacheck found issues in $rel_path (see above)" >&2
	exit 1
fi

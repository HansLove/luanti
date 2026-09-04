#!/bin/bash
# Install Hashimon API mods for use with Minetest Game (or any Luanti world).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/mods"

if [[ ! -f "$SRC/hashimon_core/init.lua" ]]; then
	echo "Missing $SRC/hashimon_core — run from 3d-world repo." >&2
	exit 1
fi

if [[ "$(uname)" == "Darwin" ]]; then
	USER_MODS="$HOME/Library/Application Support/minetest/mods"
	CONF="$HOME/Library/Application Support/minetest/minetest.conf"
else
	USER_MODS="${HOME}/.minetest/mods"
	CONF="${HOME}/.minetest/minetest.conf"
fi

mkdir -p "$USER_MODS"
for mod in hashimon_core hashimon_entities hashimon_bodies hashimon_bodies_dmobs hashimon_village_war hashimon_villain hashimon_ai_brain discovery_maps hashimon_qr_tree hashimon_magi hashimon_space_whales hashimon_players; do
	dest="$USER_MODS/$mod"
	if [[ -L "$dest" || -d "$dest" ]]; then
		rm -rf "$dest"
	fi
	ln -sf "$SRC/$mod" "$dest"
	echo "Installed mod: $dest -> $SRC/$mod"
done

touch "$CONF"
if ! grep -q '^secure.http_mods.*hashimon_core' "$CONF" 2>/dev/null; then
	if grep -q '^secure.http_mods' "$CONF"; then
		sed -i '' 's/^secure.http_mods.*/secure.http_mods = hashimon_core/' "$CONF" 2>/dev/null || \
		sed -i 's/^secure.http_mods.*/secure.http_mods = hashimon_core/' "$CONF"
	else
		printf '\nsecure.http_mods = hashimon_core\n' >> "$CONF"
	fi
	echo "Added secure.http_mods = hashimon_core to $CONF"
fi
if ! grep -q '^hashimon_api_url' "$CONF" 2>/dev/null; then
	printf 'hashimon_api_url = http://127.0.0.1:4000\n' >> "$CONF"
	echo "Added hashimon_api_url to $CONF"
fi

echo ""
echo "IMPORTANT: fully quit and restart Luanti after changing minetest.conf"
echo ""
echo "Use your existing Minetest world (recommended):"
echo "  1. Main menu → game MINETEST (not Hashimon)"
echo "  2. Open a world (e.g. Hashiworld) or create one with a seed you like"
echo "  3. Content DB → enable hashimon mods + discovery_maps + hashimon_qr_tree (symlinked) + mg_villages"
echo "     Required for Bob avatar: hashimon_players"
echo "     Required for /hv: hashimon_villain, hashimon_ai_brain, hashimon_bodies_dmobs"
echo "     Add to world.mt if missing:"
echo "       load_mod_hashimon_players = mods/hashimon_players"
echo "       load_mod_hashimon_villain = mods/hashimon_villain"
echo "       load_mod_hashimon_ai_brain = mods/hashimon_ai_brain"
echo "       load_mod_hashimon_bodies_dmobs = mods/hashimon_bodies_dmobs"
echo "  4. Start API: cd api && npm run dev"
echo "  5. In-game: /hashimon session → /hashimon starter → /hashimon sync"
echo "  6. QR sponsors (admin): /qr_tree place aarontolentino → /qr_tree align aarontolentino"
echo "  7. Villages: /vwar declare (inside village) to allow building for everyone"
echo ""
echo "Hashimons spawn in a grid around you — explore Minetest terrain as usual."

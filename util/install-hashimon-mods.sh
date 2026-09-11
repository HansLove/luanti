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
for mod in hashimon_core hashimon_entities hashimon_bodies hashimon_bodies_dmobs hashimon_village_war discovery_maps hashimon_qr_tree hashimon_magi hashimon_space_whales hashimon_players hashimon_wolkers hashimon_claim hashimon_towny_sync hashimon_towny_border hashimon_map_sync hashimon_war hashimon_vibing hashimon_alen hashimon_town_desk; do
	dest="$USER_MODS/$mod"
	if [[ -L "$dest" || -d "$dest" ]]; then
		rm -rf "$dest"
	fi
	ln -sf "$SRC/$mod" "$dest"
	echo "Installed mod: $dest -> $SRC/$mod"
done

# Keep stock ContentDB "towny" modpack if present. Do NOT replace it with our
# fork — Town Desk is the additive mod hashimon_town_desk (depends = towny).
if [[ ! -e "$USER_MODS/towny" ]]; then
	echo "WARNING: $USER_MODS/towny missing. Install Towny from ContentDB, then re-run."
fi

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
echo "     Add to world.mt if missing:"
echo "       load_mod_hashimon_players = mods/hashimon_players"
echo "       load_mod_hashimon_bodies_dmobs = mods/hashimon_bodies_dmobs"
echo "       load_mod_hashimon_map_sync = mods/hashimon_map_sync"
echo "  4. Start API: cd api && npm run dev"
echo "  5. In-game: /hashimon session → /hashimon starter → /hashimon sync"
echo "  6. QR sponsors (admin): /qr_tree place aarontolentino → /qr_tree align aarontolentino"
echo "  7. Villages: /vwar declare (inside village) to allow building for everyone"
echo ""
echo "Hashimons spawn in a grid around you — explore Minetest terrain as usual."

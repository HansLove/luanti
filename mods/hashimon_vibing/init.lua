-- hashimon_vibing — Vibing towers (docs/VIBING_V1.md §3), V1.
--
-- A town plants a tower INSIDE its own claim. The tower taps the YIELD of its coordinate
-- (the web shows which tier, derived from zona(x,z)). V1 is the real, placeable object:
-- town-gated, capped, defensible, visible on the in-game /map, and pushed to the API so
-- the website can draw it. Real extraction + heat (POW_YIELD) come in a later slice.
--
-- Additive + safe: reads Towny, pushes a projection over its OWN channel
-- (/internal/luanti-vibing-towers), never edits the towny mod or Lovable's map_markers.
-- MIT — Hashimon, 2026.

if not core.get_modpath("towny") or not towny then
	core.log("warning", "[hashimon_vibing] Towny not found — mod inactive.")
	return
end

local TOWERS_PER_TOWN = 1     -- V1 cap (tunable)
local PUSH_INTERVAL   = 10.0  -- s between change-detection pushes
local PUSH_FORCE      = 120.0 -- s: force a full re-push so the API self-heals
local BOOT_DELAY      = 6.0

------------------------------------------------------------------------
-- Persistent registry of towers, keyed by world-node position "x:y:z".
------------------------------------------------------------------------
local storage = core.get_mod_storage()
local towers = {}   -- ["x:y:z"] = { town = <name>, owner = <name>, x, y, z }

local function load_towers()
	local raw = storage:get_string("towers")
	if raw and raw ~= "" then
		local ok, d = pcall(core.deserialize, raw)
		if ok and type(d) == "table" then towers = d end
	end
end
local function save_towers() storage:set_string("towers", core.serialize(towers)) end
load_towers()

local function poskey(pos) return pos.x .. ":" .. pos.y .. ":" .. pos.z end

local function count_towers(town_name)
	local n = 0
	for _, t in pairs(towers) do if t.town == town_name then n = n + 1 end end
	return n
end

-- The player's town IF they are its mayor or co-mayor (only officers plant towers).
local function officer_town(name)
	local res = towny.residents[name]
	local town = res and res.town
	if not town then return nil end
	if res.has_flag and (res:has_flag(towny.RESIDENT_MAYOR) or res:has_flag(towny.RESIDENT_COMAYOR)) then
		return town
	end
	return nil
end

------------------------------------------------------------------------
-- Map marker (in-game /map) + API push
------------------------------------------------------------------------
local MARKER_SOURCE = "hashimon_vibing"
local map_ok = persistent_map ~= nil and type(persistent_map.upsert_system_marker) == "function"

local function refresh_markers()
	if not map_ok then return end
	if persistent_map.remove_all_system_markers then
		persistent_map.remove_all_system_markers(MARKER_SOURCE)
	end
	for k, t in pairs(towers) do
		persistent_map.upsert_system_marker(
			MARKER_SOURCE, k, vector.new(t.x, t.y, t.z),
			"🌱 Torre Vibing (" .. tostring(t.town) .. ")", 2, {})
	end
end

local push_dirty = true
local function mark_dirty() push_dirty = true end

local function push_towers(force)
	if not (hashimon and hashimon.push_vibing_towers and hashimon.get_server_secret) then return end
	if not force and not push_dirty then return end
	push_dirty = false
	local list = {}
	for k, t in pairs(towers) do
		list[#list + 1] = { id = k, town = t.town, owner = t.owner, x = t.x, y = t.y, z = t.z }
	end
	hashimon.push_vibing_towers(hashimon.get_server_secret(), { towers = list }, function(ok)
		if not ok then push_dirty = true end   -- retry next sweep
	end)
end

------------------------------------------------------------------------
-- The tower node
------------------------------------------------------------------------
core.register_node("hashimon_vibing:tower", {
	description = "Torre de Vibing",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -0.30, -0.5, -0.30, 0.30, 0.5, 0.30 },   -- shaft
			{ -0.45, -0.5, -0.45, 0.45, -0.35, 0.45 }, -- base
			{ -0.45, 0.35, -0.45, 0.45, 0.5, 0.45 },   -- crown
		},
	},
	tiles = { "[fill:16x16:#5FE0FF" },
	use_texture_alpha = "opaque",
	light_source = 13,
	paramtype = "light",
	is_ground_content = false,
	groups = { cracky = 2, oddly_breakable_by_hand = 2 },

	on_place = function(itemstack, placer, pointed)
		if not placer or not placer:is_player() or not pointed or pointed.type ~= "node" then
			return itemstack
		end
		local name = placer:get_player_name()
		local town = officer_town(name)
		if not town then
			core.chat_send_player(name, "Necesitas ser alcalde o co-alcalde de un pueblo para plantar una Torre de Vibing.")
			return itemstack
		end
		local pos = core.get_pointed_thing_position(pointed, true)
		local block = towny.get_block_by_pos and towny.get_block_by_pos(pos)
		if not block or block.town ~= town then
			core.chat_send_player(name, "La Torre debe colocarse DENTRO del territorio de tu pueblo.")
			return itemstack
		end
		if count_towers(town.name) >= TOWERS_PER_TOWN then
			core.chat_send_player(name, "Tu pueblo ya tiene su Torre de Vibing (límite V1).")
			return itemstack
		end
		-- Passed the gate: place the node normally; after_place_node registers it.
		return core.item_place_node(itemstack, placer, pointed)
	end,

	after_place_node = function(pos, placer)
		local block = towny.get_block_by_pos and towny.get_block_by_pos(pos)
		local town = block and block.town
		local owner = placer and placer:is_player() and placer:get_player_name() or nil
		towers[poskey(pos)] = {
			town = town and town.name or nil, owner = owner,
			x = pos.x, y = pos.y, z = pos.z,
		}
		save_towers()
		refresh_markers()
		mark_dirty()
		if owner then
			core.chat_send_player(owner, string.format(
				"🌱 Torre de Vibing plantada en X %d, Z %d. Mira en ihashima.com/map qué rinde su coordenada.",
				pos.x, pos.z))
		end
	end,

	-- Only officers of the tower's own town can remove it (enemy destruction = later, war).
	can_dig = function(pos, player)
		if not player or not player:is_player() then return true end
		local t = towers[poskey(pos)]
		if not t then return true end
		local town = officer_town(player:get_player_name())
		return town ~= nil and town.name == t.town
	end,

	on_destruct = function(pos)
		local k = poskey(pos)
		if towers[k] then
			towers[k] = nil
			save_towers()
			refresh_markers()
			mark_dirty()
		end
	end,
})

------------------------------------------------------------------------
-- /vibing — acquire a tower to plant (gated: officer of a town, under the cap).
-- V1 give-flow; later this costs Magi/energy.
------------------------------------------------------------------------
core.register_chatcommand("vibing", {
	description = "Obtén una Torre de Vibing para plantar en tu territorio.",
	privs = { towny = true },
	func = function(name)
		local town = officer_town(name)
		if not town then
			return false, "Necesitas ser alcalde o co-alcalde de un pueblo."
		end
		if count_towers(town.name) >= TOWERS_PER_TOWN then
			return false, "Tu pueblo ya tiene su Torre de Vibing (límite V1)."
		end
		local player = core.get_player_by_name(name)
		if not player then return false, "Debes estar en el mundo." end
		local left = player:get_inventory():add_item("main", "hashimon_vibing:tower")
		if not left:is_empty() then return false, "No tienes espacio en el inventario." end
		return true, "Torre de Vibing en tu inventario. Colócala DENTRO de tu territorio."
	end,
})

------------------------------------------------------------------------
-- Ticking: push to the API (on change + periodic force) and keep markers fresh.
------------------------------------------------------------------------
core.after(BOOT_DELAY, function() push_towers(true); refresh_markers() end)

local acc, force_acc = 0, 0
core.register_globalstep(function(dtime)
	acc = acc + dtime
	force_acc = force_acc + dtime
	if acc < PUSH_INTERVAL then return end
	acc = 0
	local force = false
	if force_acc >= PUSH_FORCE then force_acc = 0; force = true end
	push_towers(force)
end)

core.log("action", "[hashimon_vibing] loaded. /vibing to get a tower; plant it in your claim.")

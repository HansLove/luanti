-- hashimon_towny_border
-- Companion to the Towny modpack: lets a player SEE the boundary of their
-- town's claimed area as glowing perimeter walls, and shows every town's
-- center on the discovery_maps /map.
--
-- This mod is ADDITIVE. It only READS Towny's runtime data
-- (towny.town_array / towny.residents / towny.get_townblock_by_pos) and never
-- modifies a town, a claim, or a permission. Safe to enable/disable at will.
--
-- MIT — Hashimon, 2026. Builds on Towny (MIT, Evert Prants / Olivia May).

if not core.get_modpath("towny") or not towny then
	core.log("warning", "[hashimon_towny_border] Towny not found — mod inactive.")
	return
end

local bs = (towny.settings and towny.settings.town_block_size) or 16

------------------------------------------------------------------------
-- Tunables
------------------------------------------------------------------------
local REFRESH        = 2.0        -- seconds between in-world wall refreshes
local VIEW_RADIUS    = 72         -- only draw perimeter faces within this range of the player
local WALL_COLOR     = "#5FE0FFCC"-- translucent cyan (RRGGBBAA)
local WALL_TEXTURE   = "[fill:8x8:" .. WALL_COLOR   -- procedural, no PNG needed
local WALL_AMOUNT    = 60         -- particles per face per refresh
local WALL_GLOW      = 13         -- visible at night (0..14)
local WALL_SIZE_MIN  = 1.4
local WALL_SIZE_MAX  = 2.4

local MARKER_REFRESH = 10.0       -- seconds between map-marker rebuilds
local MARKER_SOURCE  = "hashimon_towny"
local MARKER_COLOR   = 3          -- index into persistent_map.marker_colors (falls back if invalid)

------------------------------------------------------------------------
-- Per-player toggle state
------------------------------------------------------------------------
local show = {}   -- [player_name] = true when border view is on

------------------------------------------------------------------------
-- Perimeter test: is the same town's claim present across a given face?
-- dx/dy/dz is the face direction in mapblock units (one of them is ±1).
------------------------------------------------------------------------
local function has_town_neighbor(block, town, dx, dy, dz)
	local p = block.pos_min
	local center = vector.new(
		p.x + bs * 0.5 + dx * bs,
		p.y + bs * 0.5 + dy * bs,
		p.z + bs * 0.5 + dz * bs
	)
	return towny.get_townblock_by_pos(center, town) ~= nil
end

-- Emit a flat particle "wall" over one 16x16 face of a claim block, for one player.
local function draw_wall(name, minp, maxp)
	core.add_particlespawner({
		amount     = WALL_AMOUNT,
		time       = REFRESH + 0.5,           -- auto-expires just after the next refresh
		minpos     = minp,
		maxpos     = maxp,
		minvel     = {x = 0, y = 0, z = 0},
		maxvel     = {x = 0, y = 0, z = 0},
		minexptime = REFRESH,
		maxexptime = REFRESH + 0.5,
		minsize    = WALL_SIZE_MIN,
		maxsize    = WALL_SIZE_MAX,
		texture    = WALL_TEXTURE,
		glow       = WALL_GLOW,
		playername = name,                    -- only this player sees their border
	})
end

-- Draw the four vertical side faces of a block that border wilderness / another town.
local function draw_block_perimeter(name, block, town)
	local p = block.pos_min
	-- +X face (east)
	if not has_town_neighbor(block, town, 1, 0, 0) then
		draw_wall(name,
			vector.new(p.x + bs, p.y, p.z),
			vector.new(p.x + bs, p.y + bs, p.z + bs))
	end
	-- -X face (west)
	if not has_town_neighbor(block, town, -1, 0, 0) then
		draw_wall(name,
			vector.new(p.x, p.y, p.z),
			vector.new(p.x, p.y + bs, p.z + bs))
	end
	-- +Z face (north)
	if not has_town_neighbor(block, town, 0, 0, 1) then
		draw_wall(name,
			vector.new(p.x, p.y, p.z + bs),
			vector.new(p.x + bs, p.y + bs, p.z + bs))
	end
	-- -Z face (south)
	if not has_town_neighbor(block, town, 0, 0, -1) then
		draw_wall(name,
			vector.new(p.x, p.y, p.z),
			vector.new(p.x + bs, p.y + bs, p.z))
	end
end

------------------------------------------------------------------------
-- Map markers (optional — only if discovery_maps is present)
------------------------------------------------------------------------
local map_ok = persistent_map ~= nil
	and type(persistent_map.upsert_system_marker) == "function"

local function refresh_town_markers()
	if not map_ok then return end
	persistent_map.remove_all_system_markers(MARKER_SOURCE)
	local ta = towny.town_array
	for i = 1, #ta do
		local town = ta[i]
		local hb = town.homeblock
		if hb and hb.pos_min then
			local c = vector.new(
				hb.pos_min.x + bs * 0.5,
				hb.pos_min.y + bs * 0.5,
				hb.pos_min.z + bs * 0.5
			)
			local label = "▩ " .. tostring(town.name) .. " (" .. tostring(#town) .. " blk)"
			persistent_map.upsert_system_marker(
				MARKER_SOURCE, "town:" .. i, c, label, MARKER_COLOR, {})
		end
	end
end

------------------------------------------------------------------------
-- Command: /border [on|off]  (toggles if no argument)
------------------------------------------------------------------------
core.register_chatcommand("border", {
	params = "[on | off]",
	description = "Show/hide glowing walls along your town's claimed boundary.",
	privs = { towny = true },
	func = function(name, param)
		param = (param or ""):gsub("%s+", ""):lower()
		if param == "on" then
			show[name] = true
		elseif param == "off" then
			show[name] = nil
		else
			show[name] = (not show[name]) or nil
		end

		if not show[name] then
			return true, "Border walls OFF."
		end

		local res = towny.residents[name]
		if not res or not res.town then
			show[name] = nil
			return false, "You are not in a town, so there is no boundary to show."
		end
		return true, "Border walls ON — the glowing edges are your town's claimed limit. Type /border off to hide."
	end,
})

------------------------------------------------------------------------
-- Ticking: refresh walls for opted-in players, and rebuild map markers.
------------------------------------------------------------------------
local wall_acc = 0
local marker_acc = MARKER_REFRESH   -- build markers on first tick

core.register_globalstep(function(dtime)
	-- in-world perimeter walls
	wall_acc = wall_acc + dtime
	if wall_acc >= REFRESH then
		wall_acc = 0
		for _, player in ipairs(core.get_connected_players()) do
			local name = player:get_player_name()
			if show[name] then
				local res = towny.residents[name]
				local town = res and res.town
				if town then
					local ppos = player:get_pos()
					for i = 1, #town do
						local block = town[i]
						if block.pos_min then
							local c = vector.new(
								block.pos_min.x + bs * 0.5,
								block.pos_min.y + bs * 0.5,
								block.pos_min.z + bs * 0.5
							)
							if vector.distance(ppos, c) <= VIEW_RADIUS then
								draw_block_perimeter(name, block, town)
							end
						end
					end
				end
			end
		end
	end

	-- map markers (one per town center)
	if map_ok then
		marker_acc = marker_acc + dtime
		if marker_acc >= MARKER_REFRESH then
			marker_acc = 0
			refresh_town_markers()
		end
	end
end)

core.register_on_leaveplayer(function(player)
	show[player:get_player_name()] = nil
end)

core.log("action", "[hashimon_towny_border] loaded. /border to toggle boundary walls."
	.. (map_ok and " Map markers: ON." or " Map markers: discovery_maps not found."))

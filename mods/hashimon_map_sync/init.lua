-- hashimon_map_sync
-- Pulls API-authoritative waypoints / nation POIs / Hashimon destinations into
-- discovery_maps, completes world-care quests on arrival, and exposes /nation home
-- with the same capital world coords the website shows.
--
-- MIT — Hashimon, 2026.

if not hashimon or not hashimon.fetch_map_markers then
	core.log("warning", "[hashimon_map_sync] hashimon_core (fetch_map_markers) not found — mod inactive.")
	return
end

local POLL_INTERVAL = 30.0
local JOIN_DELAY = 4.0
local ARRIVE_CHECK = 2.0
local BLOCK_SIZE = 16

-- Last applied quest markers per player (for proximity): { id, x, y, z, radius, label }
local quests = {}
-- Cached capital world coords from API (or Towny fallback)
local capital_cache = {}
local busy = {}
local arrive_busy = {}

local function color_for_kind(kind)
	if kind == "nation" then return 5 end      -- Purple
	if kind == "hashimon" then return 4 end    -- Yellow
	return 2                                   -- Blue (player)
end

local function apply_markers(name, markers, capital)
	if not persistent_map or not persistent_map.upsert_api_marker then
		return
	end
	local keep = {}
	local qlist = {}
	for _, m in ipairs(markers or {}) do
		if type(m) == "table" and type(m.id) == "string" then
			keep[#keep + 1] = m.id
			local pos = {
				x = tonumber(m.x) or 0,
				y = tonumber(m.y) or 8,
				z = tonumber(m.z) or 0,
			}
			persistent_map.upsert_api_marker(
				name,
				m.id,
				pos,
				m.label or "Waypoint",
				tonumber(m.colorIndex) or color_for_kind(m.kind)
			)
			if m.kind == "hashimon" then
				local meta = type(m.meta) == "table" and m.meta or {}
				qlist[#qlist + 1] = {
					id = m.id,
					x = pos.x,
					y = pos.y,
					z = pos.z,
					radius = tonumber(meta.radius) or 32,
					label = m.label or "Hashimon",
				}
			end
		end
	end
	if persistent_map.prune_api_markers then
		persistent_map.prune_api_markers(name, keep)
	end
	quests[name] = qlist

	if type(capital) == "table" and type(capital.world) == "table" then
		capital_cache[name] = {
			x = tonumber(capital.world.x),
			y = tonumber(capital.world.y),
			z = tonumber(capital.world.z),
			town = capital.townName,
		}
	end
end

local function pull(name)
	if busy[name] then return end
	if hashimon.is_api_owner and not hashimon.is_api_owner(name) then
		return
	end
	local secret = hashimon.get_server_secret and hashimon.get_server_secret()
	if not secret then return end
	busy[name] = true
	hashimon.fetch_map_markers(secret, name, function(ok, err, markers, capital)
		busy[name] = nil
		if not ok then
			core.log("info", "[hashimon_map_sync] fetch failed for " .. name .. ": " .. tostring(err))
			return
		end
		if not core.get_player_by_name(name) then return end
		apply_markers(name, markers, capital)
	end)
end

local function capital_from_towny(name)
	if not towny or not towny.residents then return nil end
	local res = towny.residents[name]
	local town = res and res.town
	if not town or not town.homeblock or not town.homeblock.blockpos then return nil end
	local bp = town.homeblock.blockpos
	local half = math.floor(BLOCK_SIZE / 2)
	return {
		x = bp.x * BLOCK_SIZE + half,
		y = bp.y * BLOCK_SIZE + half,
		z = bp.z * BLOCK_SIZE + half,
		town = town.name,
	}
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	core.after(JOIN_DELAY, function()
		if core.get_player_by_name(name) then
			pull(name)
		end
	end)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	quests[name] = nil
	capital_cache[name] = nil
	busy[name] = nil
	arrive_busy[name] = nil
end)

local poll_acc = 0
core.register_globalstep(function(dtime)
	poll_acc = poll_acc + dtime
	if poll_acc < POLL_INTERVAL then return end
	poll_acc = 0
	for _, player in ipairs(core.get_connected_players()) do
		pull(player:get_player_name())
	end
end)

-- Proximity → arrive (Hashimon world-care destinations)
local arrive_acc = 0
core.register_globalstep(function(dtime)
	arrive_acc = arrive_acc + dtime
	if arrive_acc < ARRIVE_CHECK then return end
	arrive_acc = 0
	local secret = hashimon.get_server_secret and hashimon.get_server_secret()
	if not secret or not hashimon.arrive_map_marker then return end

	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local qlist = quests[name]
		if qlist and #qlist > 0 and not arrive_busy[name] then
			local pos = player:get_pos()
			for _, q in ipairs(qlist) do
				local dx = pos.x - q.x
				local dy = pos.y - q.y
				local dz = pos.z - q.z
				local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
				if dist <= (q.radius or 32) then
					arrive_busy[name] = true
					hashimon.arrive_map_marker(secret, {
						name = name,
						markerId = q.id,
						x = pos.x,
						y = pos.y,
						z = pos.z,
					}, function(ok, err)
						arrive_busy[name] = nil
						if ok then
							core.chat_send_player(name,
								"[Hashimon] Llegaste: " .. (q.label or "destino") ..
								". Tu compañero está más contento.")
							pull(name)
						else
							core.log("info", "[hashimon_map_sync] arrive failed: " .. tostring(err))
						end
					end)
					break
				end
			end
		end
	end
end)

-- Same capital world coords as the website (API capital or Towny homeblock × 16 + 8).
core.register_chatcommand("nation", {
	params = "home",
	description = "Show your nation's capital world coordinates (same as the website map).",
	func = function(name, param)
		param = (param or ""):trim()
		if param ~= "" and param ~= "home" and param ~= "coords" then
			return false, "Usage: /nation home"
		end
		local cap = capital_cache[name] or capital_from_towny(name)
		if not cap or not cap.x then
			return false, "No tienes capital (únete o funda un pueblo)."
		end
		return true, string.format(
			"Capital%s: X=%d Y=%d Z=%d  (mismas coords que ihashima /map)",
			cap.town and (" de " .. cap.town) or "",
			math.floor(cap.x + 0.5),
			math.floor(cap.y + 0.5),
			math.floor(cap.z + 0.5)
		)
	end,
})

core.log("action", "[hashimon_map_sync] loaded — web waypoints + Hashimon destinations + /nation home")

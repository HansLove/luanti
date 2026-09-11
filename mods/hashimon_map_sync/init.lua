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
local POS_INTERVAL = 300.0 -- 5 min checkpoint while online
local BLOCK_SIZE = 16

-- Last applied quest markers per player (for proximity): { id, x, y, z, radius, label }
local quests = {}
-- Cached capital world coords from API (or Towny fallback)
local capital_cache = {}
local busy = {}
local arrive_busy = {}
local pos_busy = {}
local pos_acc = {}
local last_applied_count = {}

local function push_position(name, player)
	if pos_busy[name] then return end
	if not hashimon.push_player_position then return end
	if hashimon.is_api_owner and not hashimon.is_api_owner(name) then
		return
	end
	local secret = hashimon.get_server_secret and hashimon.get_server_secret()
	if not secret then return end
	local pos = player:get_pos()
	if not pos then return end
	pos_busy[name] = true
	hashimon.push_player_position(secret, {
		name = name,
		x = pos.x,
		y = pos.y,
		z = pos.z,
	}, function()
		pos_busy[name] = nil
	end)
end

local function color_for_kind(kind)
	if kind == "nation" then return 5 end      -- Purple
	if kind == "hashimon" then return 4 end    -- Yellow
	return 2                                   -- Blue (player)
end

local function apply_markers(name, markers, capital)
	if not persistent_map or not persistent_map.upsert_api_marker then
		core.log("warning", "[hashimon_map_sync] discovery_maps upsert missing — cannot apply web markers")
		return
	end
	if persistent_map.ensure_player_data then
		persistent_map.ensure_player_data(name)
	end
	local keep = {}
	local qlist = {}
	local applied = 0
	local failed = 0
	for _, m in ipairs(markers or {}) do
		if type(m) == "table" and type(m.id) == "string" then
			keep[#keep + 1] = m.id
			local pos = {
				x = tonumber(m.x) or 0,
				y = tonumber(m.y) or 8,
				z = tonumber(m.z) or 0,
			}
			-- JSON may arrive as colorIndex (API) or color_index
			local color = tonumber(m.colorIndex) or tonumber(m.color_index) or color_for_kind(m.kind)
			local label = m.label or m.name or "Waypoint"
			local ok, err = persistent_map.upsert_api_marker(name, m.id, pos, label, color)
			if ok then
				applied = applied + 1
			else
				failed = failed + 1
				core.log("warning",
					"[hashimon_map_sync] upsert failed for " .. name .. " id=" .. m.id
						.. " (" .. tostring(err) .. ") at "
						.. tostring(pos.x) .. "," .. tostring(pos.z))
			end
			if m.kind == "hashimon" then
				local meta = type(m.meta) == "table" and m.meta or {}
				qlist[#qlist + 1] = {
					id = m.id,
					x = pos.x,
					y = pos.y,
					z = pos.z,
					radius = tonumber(meta.radius) or 32,
					label = label,
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
			town = capital.townName or capital.town_name,
		}
	end

	core.log("action", string.format(
		"[hashimon_map_sync] %s: web markers applied=%d failed=%d total_api=%d",
		name, applied, failed, #(markers or {})
	))
	local prev = last_applied_count[name]
	last_applied_count[name] = applied
	if applied > 0 and prev ~= applied and core.get_player_by_name(name) then
		core.chat_send_player(name,
			("[Hashimon] Mapa web: %d punto(s) sincronizado(s). Abre Marker Management o /map.")
				:format(applied))
	elseif failed > 0 and core.get_player_by_name(name) then
		core.chat_send_player(name,
			("[Hashimon] Mapa web: %d punto(s) no se pudieron aplicar (mira el log).")
				:format(failed))
	end
end

local function pull(name, done)
	if busy[name] then
		if done then done(false, "busy") end
		return
	end
	-- Do not gate on can_own: waypoints live on the API by username. Guests / owners
	-- with a matching web account should sync; unknown names just get an empty list.
	local secret = hashimon.get_server_secret and hashimon.get_server_secret()
	if not secret or secret == "" then
		core.log("warning", "[hashimon_map_sync] hashimon_server_secret empty — cannot fetch markers")
		if done then done(false, "no_secret") end
		return
	end
	busy[name] = true
	hashimon.fetch_map_markers(secret, name, function(ok, err, markers, capital)
		busy[name] = nil
		if not ok then
			core.log("warning", "[hashimon_map_sync] fetch failed for " .. name .. ": " .. tostring(err))
			if done then done(false, err) end
			return
		end
		if not core.get_player_by_name(name) then
			if done then done(false, "left") end
			return
		end
		apply_markers(name, markers, capital)
		if done then done(true, nil) end
	end)
end

-- Public so Marker Management /map can force a refresh before listing.
hashimon_map_sync = hashimon_map_sync or {}
function hashimon_map_sync.pull_now(name)
	if type(name) ~= "string" or name == "" then return end
	busy[name] = nil -- allow re-entry
	pull(name)
end

--- Async pull; `done(ok, err)` runs after apply (or on early failure).
function hashimon_map_sync.pull_then(name, done)
	if type(name) ~= "string" or name == "" then
		if done then done(false, "bad_name") end
		return
	end
	busy[name] = nil
	pull(name, done)
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
	push_position(name, player)
	quests[name] = nil
	capital_cache[name] = nil
	busy[name] = nil
	arrive_busy[name] = nil
	pos_busy[name] = nil
	pos_acc[name] = nil
	last_applied_count[name] = nil
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

-- Periodic checkpoint while online (~5 min). leaveplayer also pushes.
local pos_tick = 0
core.register_globalstep(function(dtime)
	pos_tick = pos_tick + dtime
	if pos_tick < 5.0 then return end
	pos_tick = 0
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		pos_acc[name] = (pos_acc[name] or 0) + 5.0
		if pos_acc[name] >= POS_INTERVAL then
			pos_acc[name] = 0
			push_position(name, player)
		end
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
core.register_chatcommand("mapsync", {
	description = "Pull website waypoints into your in-game map now.",
	func = function(name)
		last_applied_count[name] = nil -- force chat feedback
		hashimon_map_sync.pull_now(name)
		return true, "Sincronizando puntos del mapa web…"
	end,
})

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

core.log("action", "[hashimon_map_sync] loaded — web waypoints + checkpoints + Hashimon destinations + /nation home")

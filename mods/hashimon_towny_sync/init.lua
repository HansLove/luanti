-- hashimon_towny_sync
-- Bridges the Towny world to the Hashimon API: pushes each player's territory
-- summary {town, block count, plot count, mayor} to POST /internal/luanti-territory
-- so the ihashima website can show a player their holdings.
--
-- READS Towny only (towny.residents / .town). Changes nothing in-world. The push
-- is a projection for display — never a ledger event.
--
-- MIT — Hashimon, 2026.

if not core.get_modpath("towny") or not towny then
	core.log("warning", "[hashimon_towny_sync] Towny not found — mod inactive.")
	return
end
if not hashimon or not hashimon.push_territory then
	core.log("warning", "[hashimon_towny_sync] hashimon_core (push_territory) not found — mod inactive.")
	return
end

local PUSH_INTERVAL = 5.0    -- seconds between per-player change-detection sweeps
local JOIN_DELAY    = 3.0    -- let Towny finish loading the player's town first
local TOWNS_INTERVAL = 15.0  -- seconds between whole-world town-snapshot sweeps
local TOWNS_BOOT_DELAY = 6.0 -- let storage load town_array before the first push

-- last signature pushed per player, so we only POST when something actually changed
local last_sig = {}

local function summary_for(name)
	local res = towny.residents[name]
	local town = res and res.town
	local is_mayor = false
	if res and town and res.has_flag and towny.RESIDENT_MAYOR then
		is_mayor = res:has_flag(towny.RESIDENT_MAYOR) and true or false
	end
	return {
		name           = name,
		townName       = town and town.name or nil,   -- nil → JSON null → "no town"
		townBlockCount = town and #town or 0,          -- claim blocks in the town
		ownedPlotCount = res and #res or 0,            -- plots this resident personally owns
		isMayor        = is_mayor,
	}
end

local function signature(s)
	return table.concat({
		tostring(s.townName), tostring(s.townBlockCount),
		tostring(s.ownedPlotCount), tostring(s.isMayor),
	}, "|")
end

local function push(name, force)
	-- Only players who have an API account (owner or guest) can be resolved server-side.
	if hashimon.is_api_owner and not hashimon.is_api_owner(name) then
		return
	end
	local s = summary_for(name)
	local sig = signature(s)
	if not force and last_sig[name] == sig then
		return
	end
	last_sig[name] = sig
	hashimon.push_territory(hashimon.get_server_secret(), s, function(ok, err)
		if not ok then
			-- clear the cached signature so the next sweep retries
			last_sig[name] = nil
			core.log("info", "[hashimon_towny_sync] push failed for " .. name .. ": " .. tostring(err))
		end
	end)
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	core.after(JOIN_DELAY, function()
		if core.get_player_by_name(name) then
			push(name, true)
		end
	end)
end)

local acc = 0
core.register_globalstep(function(dtime)
	acc = acc + dtime
	if acc < PUSH_INTERVAL then
		return
	end
	acc = 0
	for _, player in ipairs(core.get_connected_players()) do
		push(player:get_player_name(), false)
	end
end)

core.register_on_leaveplayer(function(player)
	last_sig[player:get_player_name()] = nil
end)

-- ---------------------------------------------------------------------------
-- Whole-world town snapshot: every town in towny.town_array with its claimed
-- mapblocks, pushed independent of who is logged in. Powers the complete ranking
-- and the web cadastral (chunk) map. Read-only on Towny; a display projection.
-- ---------------------------------------------------------------------------

-- Build {mayorName, memberCount} per town object in a single pass over residents.
local function town_membership()
	local mayor, members = {}, {}
	for name, res in pairs(towny.residents or {}) do
		local town = res.town
		if town then
			members[town] = (members[town] or 0) + 1
			if not mayor[town] and res.has_flag and towny.RESIDENT_MAYOR
				and res:has_flag(towny.RESIDENT_MAYOR) then
				mayor[town] = name
			end
		end
	end
	return mayor, members
end

-- Full roster of a town with each member's political rank (mirrors Towny flags).
local function town_roster(town)
	local list = {}
	for name, res in pairs(towny.residents or {}) do
		if res.town == town then
			local rank = "resident"
			if res.has_flag and towny.RESIDENT_MAYOR and res:has_flag(towny.RESIDENT_MAYOR) then
				rank = "mayor"
			elseif res.has_flag and towny.RESIDENT_COMAYOR and res:has_flag(towny.RESIDENT_COMAYOR) then
				rank = "comayor"
			end
			list[#list + 1] = { name = name, rank = rank }
		end
	end
	return list
end

-- Project towny.town_array into the API payload. Blocks are the claimed mapblocks
-- as {x,y,z} (3D): a sky-island claim and the ground below it stay distinct.
local function towns_payload()
	local mayor, members = town_membership()
	local towns = {}
	for _, town in ipairs(towny.town_array or {}) do
		if town.name then
			local seen, blocks = {}, {}
			for i = 1, #town do
				local bp = town[i] and town[i].blockpos
				if bp then
					local key = bp.x .. ":" .. bp.y .. ":" .. bp.z
					if not seen[key] then
						seen[key] = true
						blocks[#blocks + 1] = { bp.x, bp.y, bp.z }
					end
				end
			end
			local home = town.homeblock and town.homeblock.blockpos
			towns[#towns + 1] = {
				name        = town.name,
				blockCount  = #town,
				memberCount = members[town] or 0,
				mayor       = mayor[town] or nil,
				home        = home and { home.x, home.y, home.z } or nil,
				blocks      = blocks,
				members     = town_roster(town),
			}
		end
	end
	return towns
end

-- Signature so we only POST when the town set actually changed. Cheap and stable:
-- name + block count + homeblock is enough to catch claim/unclaim/found/delete.
local function towns_signature(towns)
	local parts = {}
	for _, t in ipairs(towns) do
		local h = t.home and (t.home[1] .. "," .. t.home[2] .. "," .. t.home[3]) or "-"
		local ranks = {}
		for _, m in ipairs(t.members or {}) do ranks[#ranks + 1] = m.name .. ":" .. m.rank end
		table.sort(ranks)
		parts[#parts + 1] = t.name .. "#" .. t.blockCount .. "#" .. h .. "#" .. table.concat(ranks, ",")
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

local last_towns_sig = nil

local function push_towns(force)
	local towns = towns_payload()
	local sig = towns_signature(towns)
	if not force and last_towns_sig == sig then
		return
	end
	last_towns_sig = sig
	hashimon.push_towns(hashimon.get_server_secret(), { towns = towns }, function(ok, err)
		if not ok then
			last_towns_sig = nil  -- retry next sweep
			core.log("info", "[hashimon_towny_sync] towns push failed: " .. tostring(err))
		end
	end)
end

core.after(TOWNS_BOOT_DELAY, function() push_towns(true) end)

local towns_acc = 0
core.register_globalstep(function(dtime)
	towns_acc = towns_acc + dtime
	if towns_acc < TOWNS_INTERVAL then
		return
	end
	towns_acc = 0
	push_towns(false)
end)

core.log("action", "[hashimon_towny_sync] loaded. Pushing town summaries + world snapshot to the API.")

-- ---------------------------------------------------------------------------
-- Political actions from the WEBSITE (co-mayor promote/demote). Poll the API,
-- RE-VALIDATE each against live Towny (the source of truth), apply the rank flag
-- and ack. The web only *requests*; Towny decides what actually holds.
-- ---------------------------------------------------------------------------
local ACTIONS_INTERVAL = 4.0

-- Resident by name, case-insensitive (web usernames may differ in case).
local function resident_ci(name)
	if not name then return nil end
	local r = towny.residents[name]
	if r then return r end
	local lower = name:lower()
	for n, res in pairs(towny.residents or {}) do
		if n:lower() == lower then return res end
	end
	return nil
end

local function has_mayor(res)
	return res and res.has_flag and towny.RESIDENT_MAYOR and res:has_flag(towny.RESIDENT_MAYOR) and true or false
end

-- Apply one action; returns "applied"|"rejected", detail.
local function apply_town_action(a)
	local get = towny.get_town_by_name
	local town = get and get(a.town_name)
	if not town then return "rejected", "no_town" end
	local actor = resident_ci(a.actor)
	if not actor or actor.town ~= town then return "rejected", "actor_not_in_town" end
	if not has_mayor(actor) then return "rejected", "actor_not_mayor" end
	local target = resident_ci(a.target)
	if not target or target.town ~= town then return "rejected", "target_not_member" end
	if has_mayor(target) then return "rejected", "target_is_mayor" end
	if a.rank ~= "comayor" or not towny.RESIDENT_COMAYOR then return "rejected", "bad_rank" end
	if a.op == "add" then
		target:add_flag(towny.RESIDENT_COMAYOR)
	elseif a.op == "remove" then
		target:remove_flag(towny.RESIDENT_COMAYOR)
	else
		return "rejected", "bad_op"
	end
	return "applied", a.op .. " comayor " .. tostring(a.target)
end

local actions_acc = 0
local actions_busy = false
core.register_globalstep(function(dtime)
	actions_acc = actions_acc + dtime
	if actions_acc < ACTIONS_INTERVAL then return end
	actions_acc = 0
	if actions_busy then return end
	actions_busy = true
	hashimon.fetch_town_actions(hashimon.get_server_secret(), function(ok, err, actions)
		actions_busy = false
		if not ok then return end
		local applied_any = false
		for _, a in ipairs(actions or {}) do
			local result, detail = apply_town_action(a)
			if result == "applied" then applied_any = true end
			hashimon.ack_town_action(hashimon.get_server_secret(), a.id, result, detail)
		end
		-- reflect the new roster on the web promptly
		if applied_any then last_towns_sig = nil end
	end)
end)

core.log("action", "[hashimon_towny_sync] political-action poll active (web co-mayor changes).")

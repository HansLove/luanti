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
local TOWNS_FORCE_INTERVAL = 120.0 -- force a full re-push this often so the API projection
                                   -- self-heals if it ever loses data (restart/clear/downtime)

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
			local invites = {}
			for iname in pairs(town.invites or {}) do
				invites[#invites + 1] = iname
			end
			table.sort(invites)
			towns[#towns + 1] = {
				name        = town.name,
				blockCount  = #town,
				memberCount = members[town] or 0,
				mayor       = mayor[town] or nil,
				home        = home and { home.x, home.y, home.z } or nil,
				blocks      = blocks,
				members     = town_roster(town),
				invites     = invites,
			}
		end
	end
	return towns
end

-- Signature so we only POST when the town set actually changed.
-- Includes a fingerprint of block coords so claim/unclaim always pushes.
local function towns_signature(towns)
	local parts = {}
	for _, t in ipairs(towns) do
		local h = t.home and (t.home[1] .. "," .. t.home[2] .. "," .. t.home[3]) or "-"
		local ranks = {}
		for _, m in ipairs(t.members or {}) do ranks[#ranks + 1] = m.name .. ":" .. m.rank end
		table.sort(ranks)
		local inv = {}
		for _, n in ipairs(t.invites or {}) do inv[#inv + 1] = n end
		table.sort(inv)
		local bkeys = {}
		for _, b in ipairs(t.blocks or {}) do
			bkeys[#bkeys + 1] = tostring(b[1]) .. "," .. tostring(b[2]) .. "," .. tostring(b[3])
		end
		table.sort(bkeys)
		parts[#parts + 1] = t.name .. "#" .. t.blockCount .. "#" .. h .. "#"
			.. table.concat(ranks, ",") .. "#" .. table.concat(inv, ",") .. "#"
			.. table.concat(bkeys, ";")
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
local force_acc = 0
core.register_globalstep(function(dtime)
	towns_acc = towns_acc + dtime
	force_acc = force_acc + dtime
	if towns_acc < TOWNS_INTERVAL then
		return
	end
	towns_acc = 0
	local force = false
	if force_acc >= TOWNS_FORCE_INTERVAL then force_acc = 0; force = true end
	push_towns(force)
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

local function has_comayor(res)
	return res and res.has_flag and towny.RESIDENT_COMAYOR and res:has_flag(towny.RESIDENT_COMAYOR) and true or false
end

local function is_officer(res)
	return has_mayor(res) or has_comayor(res)
end

-- Ensure a resident object exists for an offline invitee name (Towny may not have them yet).
local function ensure_resident(name)
	local r = resident_ci(name)
	if r then return r end
	if towny.resident and towny.resident.new then
		return towny.resident.new(name)
	end
	return nil
end

-- Apply one action; returns "applied"|"rejected", detail.
local function apply_town_action(a)
	local get = towny.get_town_by_name
	local op = a.op

	-- Membership / invite ops
	if op == "invite" then
		local town = get and get(a.town_name)
		if not town then return "rejected", "no_town" end
		local actor = resident_ci(a.actor)
		if not actor or actor.town ~= town or not is_officer(actor) then
			return "rejected", "actor_not_officer"
		end
		local target = ensure_resident(a.target)
		if not target then return "rejected", "no_target" end
		if target.town then return "rejected", "target_in_town" end
		town.invites[target.name] = target
		if target.has_flag and target:has_flag(towny.RESIDENT_ONLINE) then
			core.chat_send_player(target.name,
				"Te invita el pueblo " .. town.name .. ". Abre /town para aceptar.")
		end
		towny.dirty = true
		return "applied", "invited " .. tostring(target.name)
	end

	if op == "invite_revoke" then
		local town = get and get(a.town_name)
		if not town then return "rejected", "no_town" end
		local actor = resident_ci(a.actor)
		if not actor or actor.town ~= town or not is_officer(actor) then
			return "rejected", "actor_not_officer"
		end
		local key = a.target
		local found = town.invites[key]
		if not found then
			for n in pairs(town.invites) do
				if n:lower() == (key or ""):lower() then found = town.invites[n]; key = n; break end
			end
		end
		if not found then return "rejected", "no_invite" end
		town.invites[key] = nil
		core.chat_send_player(key, "El pueblo " .. town.name .. " revocó tu invitación.")
		towny.dirty = true
		return "applied", "revoked " .. key
	end

	if op == "invite_accept" then
		local town = get and get(a.town_name)
		if not town then return "rejected", "no_town" end
		local actor = resident_ci(a.actor) or ensure_resident(a.actor)
		if not actor then return "rejected", "no_actor" end
		if actor.town then return "rejected", "already_in_town" end
		if not town.invites[actor.name] then
			local ok = false
			for n, inv in pairs(town.invites) do
				if n:lower() == actor.name:lower() then
					town.invites[n] = nil
					ok = true
					break
				end
			end
			if not ok then return "rejected", "no_invite" end
		else
			town.invites[actor.name] = nil
		end
		town:add_resident(actor)
		towny.dirty = true
		towny.chat_send_town(town, actor.name .. " se unió al pueblo!")
		return "applied", "joined " .. town.name
	end

	if op == "invite_deny" then
		local town = get and get(a.town_name)
		if not town then return "rejected", "no_town" end
		local actor = resident_ci(a.actor)
		local key = actor and actor.name or a.actor
		if town.invites[key] then
			town.invites[key] = nil
		else
			for n in pairs(town.invites) do
				if n:lower() == (key or ""):lower() then town.invites[n] = nil; break end
			end
		end
		towny.dirty = true
		return "applied", "denied"
	end

	if op == "kick" then
		local town = get and get(a.town_name)
		if not town then return "rejected", "no_town" end
		local actor = resident_ci(a.actor)
		if not actor or actor.town ~= town or not is_officer(actor) then
			return "rejected", "actor_not_officer"
		end
		local target = resident_ci(a.target)
		if not target or target.town ~= town then return "rejected", "target_not_member" end
		if has_mayor(target) then return "rejected", "cannot_kick_mayor" end
		town:remove_resident(target)
		towny.dirty = true
		return "applied", "kicked " .. target.name
	end

	if op == "leave" then
		local town = get and get(a.town_name)
		if not town then return "rejected", "no_town" end
		local actor = resident_ci(a.actor)
		if not actor or actor.town ~= town then return "rejected", "actor_not_in_town" end
		if has_mayor(actor) then return "rejected", "mayor_cannot_leave" end
		town:remove_resident(actor)
		towny.dirty = true
		return "applied", "left"
	end

	-- Web claim: target is "bx,by,bz" mapblock. Actor need not be online; must be officer.
	-- Conquista. La decide la API (la batalla ya se resolvió y está firmada con su semilla);
	-- aquí el mundo la APLICA y, como con todo lo que llega de fuera, la revalida. El actor
	-- es "war", no una persona, así que la comprobación de oficial no aplica: lo que
	-- autoriza esta acción es haber ganado, no un rango.
	--
	-- Tres cosas se niegan aunque la API las pida, y las tres son del mundo, no del juego:
	--   · un chunk que no toca tu frontera — conquistar no teletransporta territorio;
	--   · el homeblock del defensor — una capital no se toma pieza a pieza, y además
	--     `town.homeblock` quedaría apuntando a un bloque borrado;
	--   · pasarte de tu propio límite de bloques — si la guerra saltara el tope, la guerra
	--     sería la forma de saltarse todos los topes.
	if op == "war_claim" then
		local town = get and get(a.town_name)
		if not town then return "rejected", "no_town" end

		local bx, by, bz = tostring(a.target or ""):match("^(-?%d+),(-?%d+),(-?%d+)$")
		if not bx then return "rejected", "bad_target" end
		bx, by, bz = tonumber(bx), tonumber(by), tonumber(bz)
		local bs = (towny.settings and towny.settings.town_block_size) or 16
		local center = vector.new(bx * bs + bs * 0.5, by * bs + bs * 0.5, bz * bs + bs * 0.5)

		local max_blocks = towny.settings.max_townblocks or 64
		if #town >= max_blocks then
			return "rejected", "limit"
		end
		if not towny.pos_borders_townblock(center, town) then
			return "rejected", "not_adjacent"
		end

		local held = towny.get_block_by_pos(center)
		local loser = nil
		if held then
			if held.town == town then
				-- Ya era nuestro: la batalla se ganó y el chunk llegó por otra vía. No es
				-- un fallo, es una carrera, y se contesta como aplicada para que la API no
				-- reintente eternamente.
				return "applied", string.format("already ours %d,%d,%d", bx, by, bz)
			end
			if held.flags and towny.has_flag(held.flags, towny.BLOCK_HOMEBLOCK) then
				return "rejected", "homeblock"
			end
			loser = held.town
			local ok_del, err_del = pcall(function() held:delete(true) end)
			if not ok_del then
				core.log("warning", "[hashimon_towny_sync] war unclaim failed: " .. tostring(err_del))
				return "rejected", "unclaim_failed"
			end
		end

		local ok, err = pcall(function() towny.block.new(center, town) end)
		if not ok then
			core.log("warning", "[hashimon_towny_sync] war claim failed: " .. tostring(err))
			return "rejected", "claim_failed"
		end
		towny.dirty = true

		-- Una guerra que nadie ve no es una guerra. Los dos pueblos se enteran en el chat,
		-- y el que pierde se entera de quién se lo llevó.
		towny.chat_send_town(town, string.format("Habéis tomado el chunk %d,%d — %s.",
			bx, bz, loser and ("era de " .. loser.name) or "tierra de nadie"))
		if loser then
			towny.chat_send_town(loser, string.format("%s os ha arrebatado el chunk %d,%d.",
				town.name, bx, bz))
		end
		core.log("action", string.format("[hashimon_towny_sync] war_claim %d,%d,%d → %s (de %s)",
			bx, by, bz, town.name, loser and loser.name or "nadie"))
		return "applied", string.format("conquered %d,%d,%d from %s",
			bx, by, bz, loser and loser.name or "nobody")
	end

	if op == "claim" then
		local town = get and get(a.town_name)
		if not town then return "rejected", "no_town" end
		local actor = resident_ci(a.actor)
		if not actor or actor.town ~= town or not is_officer(actor) then
			return "rejected", "actor_not_officer"
		end
		local bx, by, bz = tostring(a.target or ""):match("^(-?%d+),(-?%d+),(-?%d+)$")
		if not bx then return "rejected", "bad_target" end
		bx, by, bz = tonumber(bx), tonumber(by), tonumber(bz)
		local bs = (towny.settings and towny.settings.town_block_size) or 16
		local center = vector.new(bx * bs + bs * 0.5, by * bs + bs * 0.5, bz * bs + bs * 0.5)

		-- Block-limit: offline actors have no privs → use the default cap.
		local max_blocks = towny.settings.max_townblocks or 64
		if #town >= max_blocks then
			return "rejected", "limit"
		end
		if towny.get_block_by_pos(center) then
			return "rejected", "already_claimed"
		end
		if not towny.settings.vertical_towns then
			local other = towny.exists_block_at_x_z(center)
			if other and other.town ~= town then
				return "rejected", "vertical_conflict"
			end
		end
		if not towny.pos_borders_townblock(center, town) then
			return "rejected", "not_adjacent"
		end

		local ok, err = pcall(function()
			local block = towny.block.new(center, town)
			if towny.neighboring_townblocks_have_flag(town, block, towny.BLOCK_OUTPOST) then
				if towny.neighboring_townblocks_have_flag(town, block, towny.BLOCK_OUTPOST, true) then
					for i = 1, #town do
						town[i]:remove_flag(towny.BLOCK_OUTPOST)
					end
				else
					block:add_flag(towny.BLOCK_OUTPOST)
				end
			end
		end)
		if not ok then
			core.log("warning", "[hashimon_towny_sync] web claim failed: " .. tostring(err))
			return "rejected", "claim_failed"
		end
		towny.dirty = true
		return "applied", string.format("claimed %d,%d,%d (#%d)", bx, by, bz, #town)
	end

	-- Rank ops (comayor add/remove) — mayor only
	local town = get and get(a.town_name)
	if not town then return "rejected", "no_town" end
	local actor = resident_ci(a.actor)
	if not actor or actor.town ~= town then return "rejected", "actor_not_in_town" end
	if not has_mayor(actor) then return "rejected", "actor_not_mayor" end
	local target = resident_ci(a.target)
	if not target or target.town ~= town then return "rejected", "target_not_member" end
	if has_mayor(target) then return "rejected", "target_is_mayor" end
	if a.rank ~= "comayor" or not towny.RESIDENT_COMAYOR then return "rejected", "bad_rank" end
	if op == "add" then
		target:add_flag(towny.RESIDENT_COMAYOR)
	elseif op == "remove" then
		target:remove_flag(towny.RESIDENT_COMAYOR)
	else
		return "rejected", "bad_op"
	end
	return "applied", op .. " comayor " .. tostring(a.target)
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
		local claimed_any = false
		for _, a in ipairs(actions or {}) do
			local result, detail = apply_town_action(a)
			if result == "applied" then
				applied_any = true
				if a.op == "claim" or a.op == "war_claim" then claimed_any = true end
			end
			hashimon.ack_town_action(hashimon.get_server_secret(), a.id, result, detail)
		end
		-- Roster/ranks: mark dirty for next sweep. Claims: push NOW so the web map
		-- does not wait up to TOWNS_INTERVAL (15s) to see the new block.
		if claimed_any then
			push_towns(true)
		elseif applied_any then
			last_towns_sig = nil
		end
	end)
end)

core.log("action", "[hashimon_towny_sync] political-action poll active (ranks + invites + kick/leave + claim + war_claim).")

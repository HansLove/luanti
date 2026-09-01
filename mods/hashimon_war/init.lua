-- hashimon_war  —  Risk-style V1 warfare for Towny (no Magi; economy is V2).
--
-- The Risk loop, in one breath:
--   * Two towns whose claims touch (mapblock-adjacent) are AUTOMATICALLY at war.
--   * Territory MUSTERS troops (fichas) over time — more land, more troops, but you
--     must wait to amass them. Troops accrue into the town's reserve pool.
--   * You DEPLOY troops from the pool into your claimed quadrants (the "acomodo de
--     fichas"): pile them on the hot frontier, leave the interior light.
--   * You ATTACK an adjacent enemy quadrant from one of yours: classic Risk dice
--     (attacker rolls min(troops-1,cap), defender min(troops,2) + home/compact bonus,
--     ties to the defender). The loser removes fichas. When a quadrant hits 0 fichas
--     it is CAPTURED — the claim transfers to you and you move fichas in.
--   * The capital (homeblock) can never be captured — the last bastion.
--
-- The whole thing is driven from a /war FORMSPEC panel (see the dice, deploy and
-- attack with buttons) instead of typing in chat. Troop counts also float over the
-- quadrants as a HUD so you can SEE where armies are massed (yours and the enemy's).
--
-- SAFE: reads Towny runtime data; the only mutations are Towny's own block:delete /
-- block.new to transfer a captured, non-home quadrant. MIT — Hashimon, 2026.
-- Builds on Towny (MIT, Evert Prants / Olivia May).

if not core.get_modpath("towny") or not towny then
	core.log("warning", "[hashimon_war] Towny not found — mod inactive.")
	return
end

local bs = (towny.settings and towny.settings.town_block_size) or 16
local F = core.formspec_escape

------------------------------------------------------------------------
-- Tunables — LIVE. `minetest.conf` key `hashimon_war_<key>` overrides a default
-- at load; `/war tune <key> <value>` (server priv) changes it at runtime with no
-- restart. `/war debug` prints the live values. Intents baked into the defaults:
--   * numbers beat defense: max_atk (5) > max_def (3) — enough fichas break anything.
--   * territory funds war but slowly: muster ~ blocks/muster_div per muster_interval.
--   * over-extension weakens: a sprawled town (blocks > e_soft) loses a defense die.
------------------------------------------------------------------------
local DEFAULTS = {
	cooldown        = 4,    -- s between one player's attacks
	presence_radius = 48,   -- nodes: who counts as a "present defender" (bonus die)
	e_soft          = 12,   -- claim blocks above which a town is over-extended
	war_scan        = 20,   -- s between collision (new-war) announcements
	max_atk         = 5,    -- max attacker dice
	max_def         = 3,    -- max defender dice
	muster_interval = 60,   -- s between troop musters
	muster_div      = 3,    -- new troops per muster = floor(#blocks / this)
	muster_min      = 1,    -- ...but at least this many if the town holds any land
	pool_cap        = 30,   -- max undeployed troops a town can bank
	garrison_cap    = 20,   -- max troops in one quadrant
	home_base       = 4,    -- troops the capital is seeded with
	hud_radius      = 64,   -- nodes: show floating troop numbers within this range
	hud_refresh     = 2,    -- s between HUD refreshes
	hud_max         = 40,   -- cap floating numbers per player (perf)
}

local cfg = {}
for k, v in pairs(DEFAULTS) do
	local s = core.settings:get("hashimon_war_" .. k)
	cfg[k] = (s and tonumber(s)) or v
end

------------------------------------------------------------------------
-- Persistent state: troops per quadrant (garrison) + each town's undeployed pool.
-- garrison is keyed by mapblock "x:y:z"; the OWNER of that position is always read
-- live from Towny, so a capture (owner flip) needs no bookkeeping here.
------------------------------------------------------------------------
local storage = core.get_mod_storage()
local garrison = {}   -- ["x:y:z"] = troop count
local pool = {}       -- [town name] = undeployed troops

local function load_state()
	local g = storage:get_string("garrison")
	if g and g ~= "" then local ok, d = pcall(core.deserialize, g); if ok and type(d) == "table" then garrison = d end end
	local p = storage:get_string("pool")
	if p and p ~= "" then local ok, d = pcall(core.deserialize, p); if ok and type(d) == "table" then pool = d end end
end
local function save_state()
	storage:set_string("garrison", core.serialize(garrison))
	storage:set_string("pool", core.serialize(pool))
end
load_state()

local function key_of(bp) return bp.x .. ":" .. bp.y .. ":" .. bp.z end
local function parse_key(k)
	local x, y, z = k:match("^(%-?%d+):(%-?%d+):(%-?%d+)$")
	if not x then return nil end
	return { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
end
local function gget(k) return garrison[k] or 0 end

------------------------------------------------------------------------
-- Geometry / Towny helpers
------------------------------------------------------------------------
local function center_of_bp(bp)
	return vector.new(bp.x * bs + bs * 0.5, bp.y * bs + bs * 0.5, bp.z * bs + bs * 0.5)
end
local function block_at(pos) return towny.get_block_by_pos(pos) end

local function present_count(town, center)
	local n = 0
	for _, player in ipairs(core.get_connected_players()) do
		local res = towny.residents[player:get_player_name()]
		if res and res.town == town and vector.distance(player:get_pos(), center) <= cfg.presence_radius then
			n = n + 1
		end
	end
	return n
end

local function is_homeblock(block)
	return block.has_flag and block:has_flag(towny.BLOCK_HOMEBLOCK) and true or false
end

------------------------------------------------------------------------
-- Dice: classic Risk resolution
------------------------------------------------------------------------
math.randomseed((core.get_us_time and core.get_us_time() or 0) + os.time())

local function roll_dice(n)
	local d = {}
	for i = 1, n do d[i] = math.random(1, 6) end
	table.sort(d, function(a, b) return a > b end)
	return d
end
-- Compare the top pairs; higher wins, TIES GO TO THE DEFENDER (as in Risk).
local function resolve(atk, def)
	local n = math.min(#atk, #def)
	local aw, dw = 0, 0
	for i = 1, n do if atk[i] > def[i] then aw = aw + 1 else dw = dw + 1 end end
	return aw, dw
end
local function dice_str(d) return "[" .. table.concat(d, ",") .. "]" end

local function announce(msg) core.chat_send_all(msg) end
local last_attack = {}   -- [name] = os.time()
local last_msg = {}      -- [name] = last war line, echoed in the panel

------------------------------------------------------------------------
-- The Risk exchange: attack front quadrant D from your quadrant A.
--   aInfo  = { town, key, count }         (attacker)
--   front  = { key, center, town, count, home }   (defender quadrant)
-- Returns (ok, message). Mutates garrison / does the capture; caller re-shows panel.
------------------------------------------------------------------------
local function attack_core(name, aInfo, front)
	local now = os.time()
	local prev = last_attack[name]
	if prev and (now - prev) < cfg.cooldown then
		return false, string.format("Espera %ds para el siguiente ataque.", math.ceil(cfg.cooldown - (now - prev)))
	end
	if front.home then
		return false, front.town.name .. ": no puedes capturar la capital. Rompe su frontera primero."
	end
	local a = aInfo.count
	if a < 2 then
		return false, "Necesitas al menos 2 fichas en tu cuadrante para atacar (una se queda)."
	end
	last_attack[name] = now
	local dt = front.town
	local d = front.count

	-- Undefended quadrant: walk in, no roll.
	if d <= 0 then
		return true, "capture", a
	end

	local center = front.center
	local compact = (#dt <= cfg.e_soft)
	local def_present = present_count(dt, center)
	local atk_n = math.max(1, math.min(cfg.max_atk, a - 1))
	local def_n = math.max(1, math.min(cfg.max_def, math.min(d, 2) + (compact and 1 or 0) + (def_present > 0 and 1 or 0)))

	local ad, dd = roll_dice(atk_n), roll_dice(def_n)
	local aw, dw = resolve(ad, dd)
	local na = math.max(0, a - dw)      -- attacker loses on defender wins
	local nd = math.max(0, d - aw)      -- defender loses on attacker wins
	garrison[aInfo.key] = na
	local line = string.format("⚔ %s %s  vs  %s %s  →  tú -%d, %s -%d",
		F(name), dice_str(ad), F(dt.name), dice_str(dd), dw, F(dt.name), aw)

	if nd <= 0 then
		-- CAPTURE: transfer the claim and move fichas in.
		garrison[front.key] = 0
		local moved = math.min(na, math.max(1, atk_n))
		local fresh = block_at(center)
		if fresh and fresh.town == dt and not is_homeblock(fresh) then
			local ok = pcall(function()
				fresh:delete()
				towny.block.new(center, aInfo.town)
			end)
			if ok then
				garrison[aInfo.key] = na - moved
				garrison[front.key] = moved
				save_state()
				announce(string.format("⚔ ¡CONQUISTA! %s tomó un cuadrante de %s.", F(aInfo.town.name), F(dt.name)))
				return true, line .. string.format("  →  ¡capturado! (moviste %d fichas)", moved)
			end
		end
		save_state()
		return true, line .. "  →  ¡el cuadrante cayó!"
	end

	garrison[front.key] = nd
	save_state()
	return true, line .. string.format("  (guarnición enemiga: %d)", nd)
end

------------------------------------------------------------------------
-- Context around where a player stands: their quadrant A + adjacent enemy fronts.
------------------------------------------------------------------------
local DIRS = { {1,0,0}, {-1,0,0}, {0,0,1}, {0,0,-1} }

local function context(name)
	local player = core.get_player_by_name(name)
	local res = towny.residents[name]
	local at = res and res.town
	if not player or not at then return { player = player, at = at } end
	local ppos = player:get_pos()
	local here = block_at(ppos)
	local inOwn = here and here.town == at
	local ctx = { player = player, at = at, inOwn = inOwn }
	if inOwn then
		local abp = here.blockpos
		ctx.a = { town = at, key = key_of(abp), count = gget(key_of(abp)), bp = abp }
		ctx.fronts = {}
		for _, dd in ipairs(DIRS) do
			local nbp = { x = abp.x + dd[1], y = abp.y, z = abp.z + dd[3] }
			local center = center_of_bp(nbp)
			local nb = block_at(center)
			if nb and nb.town ~= at and nb.town.name then
				ctx.fronts[#ctx.fronts + 1] = {
					key = key_of(nbp), center = center, town = nb.town,
					count = gget(key_of(nbp)), home = is_homeblock(nb),
				}
			end
		end
	end
	return ctx
end

------------------------------------------------------------------------
-- The /war panel (formspec)
------------------------------------------------------------------------
local panel_fronts = {}   -- [name] = { [i] = front table } for button routing
local panel_here = {}     -- [name] = attacker quadrant key for the deploy button

local function show_panel(name)
	local ctx = context(name)
	if not ctx.at then
		core.chat_send_player(name, "No tienes pueblo. La guerra es entre pueblos cuyos claims chocan.")
		return
	end
	local fs = {
		"formspec_version[4]", "size[10,8.6]",
		string.format("label[0.4,0.5;⚔ Guerra Risk — %s]", F(ctx.at.name)),
		string.format("label[0.4,1.0;Reservas (fichas sin desplegar): %d / %d]",
			pool[ctx.at.name] or 0, cfg.pool_cap),
		"box[0.3,1.4;9.4,0.02;#666]",
	}
	if ctx.inOwn then
		panel_here[name] = ctx.a.key
		fs[#fs + 1] = string.format("label[0.4,1.9;Aquí (tu cuadrante): %d fichas]", ctx.a.count)
		fs[#fs + 1] = "field[0.4,2.3;1.6,0.7;amount;;5]"
		fs[#fs + 1] = "field_close_on_enter[amount;false]"
		fs[#fs + 1] = "button[2.1,2.3;2.4,0.7;deploy;Desplegar aquí]"
		fs[#fs + 1] = "label[0.4,3.5;Frentes desde aquí:]"
		panel_fronts[name] = {}
		if #ctx.fronts == 0 then
			fs[#fs + 1] = "label[0.6,4.0;(ninguno — este cuadrante no toca territorio enemigo)]"
		else
			for i, fr in ipairs(ctx.fronts) do
				panel_fronts[name][i] = fr
				local y = 3.9 + (i - 1) * 0.8
				local tag = fr.home and "  [CAPITAL]" or ""
				fs[#fs + 1] = string.format("label[0.6,%.2f;%s — %d fichas%s]", y + 0.25, F(fr.town.name), fr.count, tag)
				if fr.home then
					fs[#fs + 1] = string.format("button[6.4,%.2f;3.0,0.7;atk_%d;Inmune]", y, i)
				else
					fs[#fs + 1] = string.format("button[6.4,%.2f;3.0,0.7;atk_%d;Atacar]", y, i)
				end
			end
		end
	else
		panel_here[name] = nil
		fs[#fs + 1] = "label[0.4,2.1;Párate dentro de un cuadrante TUYO para desplegar fichas]"
		fs[#fs + 1] = "label[0.4,2.5;o atacar un frente vecino.]"
	end
	if last_msg[name] then
		fs[#fs + 1] = string.format("label[0.4,7.4;%s]", F(last_msg[name]))
	end
	fs[#fs + 1] = "button_exit[7.5,7.9;2.0,0.6;close;Cerrar]"
	core.show_formspec(name, "hashimon_war:panel", table.concat(fs))
end

local function do_deploy(name, amount)
	local ctx = context(name)
	if not ctx.inOwn or not ctx.a then
		last_msg[name] = "Debes estar en tu propio cuadrante para desplegar."
		return
	end
	local avail = pool[ctx.at.name] or 0
	local n = math.floor(tonumber(amount) or 0)
	if n <= 0 then last_msg[name] = "Cantidad inválida." return end
	n = math.min(n, avail)
	local room = cfg.garrison_cap - ctx.a.count
	n = math.min(n, math.max(0, room))
	if n <= 0 then last_msg[name] = "Sin fichas disponibles o cuadrante lleno." return end
	pool[ctx.at.name] = avail - n
	garrison[ctx.a.key] = ctx.a.count + n
	save_state()
	last_msg[name] = string.format("Desplegaste %d fichas aquí (ahora %d).", n, garrison[ctx.a.key])
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "hashimon_war:panel" then return end
	local name = player:get_player_name()
	if fields.deploy then
		do_deploy(name, fields.amount)
		show_panel(name)
		return
	end
	for k in pairs(fields) do
		local idx = k:match("^atk_(%d+)$")
		if idx then
			-- Re-derive the front FRESH from where the player stands now, matching the
			-- clicked front by position — so troop counts / ownership are never stale.
			local stored = panel_fronts[name] and panel_fronts[name][tonumber(idx)]
			local ctx = context(name)
			local fr = nil
			if stored and ctx.inOwn and ctx.fronts then
				for _, f in ipairs(ctx.fronts) do if f.key == stored.key then fr = f; break end end
			end
			if fr and ctx.a then
				local ok, msg, cap = attack_core(name, ctx.a, fr)
				if ok and msg == "capture" then
					-- undefended: capture immediately
					local moved = math.min(cap, math.max(1, cap - 1))
					local fresh = block_at(fr.center)
					if fresh and fresh.town == fr.town and not is_homeblock(fresh) then
						local okc = pcall(function() fresh:delete(); towny.block.new(fr.center, ctx.a.town) end)
						if okc then
							garrison[ctx.a.key] = cap - moved
							garrison[fr.key] = moved
							save_state()
							announce(string.format("⚔ ¡CONQUISTA! %s ocupó un cuadrante vacío de %s.", F(ctx.a.town.name), F(fr.town.name)))
							last_msg[name] = string.format("Cuadrante vacío capturado (moviste %d fichas).", moved)
						end
					end
				else
					last_msg[name] = msg
				end
			else
				last_msg[name] = "Ya no estás junto a ese frente."
			end
			show_panel(name)
			return
		end
	end
end)

------------------------------------------------------------------------
-- Chat: /war (opens panel) | status | debug | tune
------------------------------------------------------------------------
local function cmd_status(name)
	local res = towny.residents[name]
	local at = res and res.town
	if not at then return true, "No tienes pueblo. La guerra es entre pueblos cuyos claims chocan." end
	local enemies = {}
	for i = 1, #at do
		local bp = at[i].blockpos
		for _, d in ipairs(DIRS) do
			local nb = block_at(center_of_bp({ x = bp.x + d[1], y = bp.y, z = bp.z + d[3] }))
			if nb and nb.town ~= at and nb.town.name then enemies[nb.town.name] = true end
		end
	end
	local list = {}
	for tn in pairs(enemies) do list[#list + 1] = tn end
	local troops = 0
	for i = 1, #at do troops = troops + gget(key_of(at[i].blockpos)) end
	local msg = string.format("%s — fichas desplegadas: %d, reserva: %d.", at.name, troops, pool[at.name] or 0)
	if #list > 0 then msg = msg .. " En guerra con: " .. table.concat(list, ", ") .. "."
	else msg = msg .. " En paz (sin fronteras en contacto)." end
	return true, msg
end

local function cmd_debug(name)
	local keys = {}
	for k in pairs(DEFAULTS) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(cfg[k]) end
	return true, "hashimon_war: " .. table.concat(parts, "  ")
end

local function cmd_tune(name, key, value)
	if not core.check_player_privs(name, { server = true }) then
		return false, "Ajustar el balance necesita el privilegio 'server'."
	end
	if not key or DEFAULTS[key] == nil then return false, "Knob desconocido. Ver /war debug." end
	local n = tonumber(value)
	if not n then return false, "El valor debe ser un número, p.ej. /war tune muster_div 2" end
	cfg[key] = n
	return true, string.format("Set %s = %s (en vivo).", key, tostring(n))
end

core.register_chatcommand("war", {
	params = "[ | status | debug | tune <key> <value>]",
	description = "Guerra Risk: abre el panel para desplegar fichas y atacar; status/debug/tune.",
	func = function(name, param)
		local args = {}
		for w in (param or ""):gmatch("%S+") do args[#args + 1] = w end
		local sub = (args[1] or ""):lower()
		if sub == "status" then return cmd_status(name) end
		if sub == "debug" then return cmd_debug(name) end
		if sub == "tune" then return cmd_tune(name, args[2], args[3]) end
		show_panel(name)
		return true
	end,
})

------------------------------------------------------------------------
-- Muster: towns bank troops over time (~ #blocks / muster_div). Also seeds each
-- capital's garrison, and prunes state for vanished towns / unclaimed quadrants.
------------------------------------------------------------------------
local muster_acc = 0
core.register_globalstep(function(dtime)
	muster_acc = muster_acc + dtime
	if muster_acc < cfg.muster_interval then return end
	muster_acc = 0
	local ta = towny.town_array or {}
	local live_towns = {}
	for i = 1, #ta do
		local town = ta[i]
		if town.name then
			live_towns[town.name] = true
			-- seed capital garrison once
			if town.homeblock and town.homeblock.blockpos then
				local hk = key_of(town.homeblock.blockpos)
				if garrison[hk] == nil then garrison[hk] = cfg.home_base end
			end
			-- muster into the pool
			local gain = math.max(cfg.muster_min, math.floor(#town / cfg.muster_div))
			pool[town.name] = math.min(cfg.pool_cap, (pool[town.name] or 0) + gain)
		end
	end
	-- prune pools of deleted towns
	for tn in pairs(pool) do if not live_towns[tn] then pool[tn] = nil end end
	-- prune garrisons on quadrants that are no longer claimed
	for k in pairs(garrison) do
		local bp = parse_key(k)
		if not bp or not block_at(center_of_bp(bp)) then garrison[k] = nil end
	end
	save_state()
end)

------------------------------------------------------------------------
-- HUD: float each garrisoned quadrant's troop count in the world (yours cyan,
-- enemy red) so you SEE where fichas are massed. Refreshed on a throttle.
------------------------------------------------------------------------
local hud_ids = {}   -- [name] = { id, ... }
local hud_acc = 0
core.register_globalstep(function(dtime)
	hud_acc = hud_acc + dtime
	if hud_acc < cfg.hud_refresh then return end
	hud_acc = 0
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		-- clear previous
		if hud_ids[name] then
			for _, id in ipairs(hud_ids[name]) do player:hud_remove(id) end
		end
		hud_ids[name] = {}
		local res = towny.residents[name]
		local at = res and res.town
		local ppos = player:get_pos()
		local shown = 0
		local ta = towny.town_array or {}
		for i = 1, #ta do
			if shown >= cfg.hud_max then break end
			local town = ta[i]
			for j = 1, #town do
				if shown >= cfg.hud_max then break end
				local bp = town[j].blockpos
				local g = gget(key_of(bp))
				if g > 0 then
					local center = center_of_bp(bp)
					if vector.distance(ppos, center) <= cfg.hud_radius then
						local color = (town == at) and 0x5FE0FF or 0xFF5A5A
						local id = player:hud_add({
							hud_elem_type = "waypoint",
							name = tostring(g),
							text = "",
							precision = 0,     -- hide the distance suffix
							number = color,
							world_pos = center,
						})
						if id then hud_ids[name][#hud_ids[name] + 1] = id; shown = shown + 1 end
					end
				end
			end
		end
	end
end)

------------------------------------------------------------------------
-- Collision watch: announce when two towns' borders first touch (auto-war).
------------------------------------------------------------------------
local known_wars = {}
local function pair_key(a, b) if a < b then return a .. "|" .. b else return b .. "|" .. a end end
local war_acc = 0
core.register_globalstep(function(dtime)
	war_acc = war_acc + dtime
	if war_acc < cfg.war_scan then return end
	war_acc = 0
	local ta = towny.town_array or {}
	local seen = {}
	for i = 1, #ta do
		local town = ta[i]
		for j = 1, #town do
			local bp = town[j].blockpos
			for _, d in ipairs(DIRS) do
				local nb = block_at(center_of_bp({ x = bp.x + d[1], y = bp.y, z = bp.z + d[3] }))
				if nb and nb.town ~= town and nb.town.name and town.name then
					local pk = pair_key(town.name, nb.town.name)
					seen[pk] = true
					if not known_wars[pk] then
						known_wars[pk] = true
						announce(string.format("⚔ ¡GUERRA! Las fronteras de %s y %s chocaron. Su frontera está en disputa.",
							F(town.name), F(nb.town.name)))
					end
				end
			end
		end
	end
	for pk in pairs(known_wars) do if not seen[pk] then known_wars[pk] = nil end end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	last_attack[name] = nil
	panel_fronts[name] = nil
	panel_here[name] = nil
	if hud_ids[name] then
		for _, id in ipairs(hud_ids[name]) do player:hud_remove(id) end
		hud_ids[name] = nil
	end
end)

core.log("action", "[hashimon_war] loaded (Risk V1: muster + deploy + capture). /war opens the panel.")

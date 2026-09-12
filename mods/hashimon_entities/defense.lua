-- Guard behaviour: a Hashimon defends its owner, Minecraft-wolf style, and the
-- rider's own ranged attack while mounted.
--
-- Two halves, one aggro model:
--
--   1. DEFENSA. When the owner is punched by anything that is not one of their
--      own creatures, every spawned Hashimon of that owner takes the attacker
--      as its target for GUARD.memory seconds: it breaks off following, closes
--      in, bites at melee range, and — once grown enough — throws elemental
--      cubes from range. Punching a Hashimon directly aggroes it too. The
--      target is dropped when it dies, leaves aggro range, or the leash to the
--      owner stretches too far (guards come home; they do not wander off).
--
--   2. ATAQUE MONTADO. While riding, left click throws one elemental cube in
--      the look direction, on a cooldown. The cube's colour, opacity, damage
--      and status effect come from the mount's element (element_cube.lua).
--
-- Movement here is velocity-driven, which covers the sprite and procedural
-- voxel render tiers. Creatura-backed morphology bodies keep their animations
-- and pathfinding, so they guard through a Creatura utility instead —
-- hashimon_bodies/guard.lua — reusing every helper in this file.

hashimon = hashimon or {}

hashimon.CUBE_COOLDOWN = 1.2 -- rider's left-click cube (seconds)

hashimon.GUARD = {
	enabled = true, -- server-wide switch (/hashimon guard server off)
	memory = 12, -- seconds a guard remembers its target
	aggro_radius = 20, -- give up when the target is farther than this
	leash = 26, -- give up when we strayed this far from the owner
	melee_range = 2.6,
	melee_damage = 4, -- before stage scaling
	melee_interval = 1.0,
	melee_knockback = 4,
	approach_speed = 6.5, -- nodes/sec while closing in
	ranged_min_range = 6, -- only throw cubes from at least this far
	ranged_cooldown = 2.5,
	ranged_stage_min = 3, -- below this stage a Hashimon only bites
	guard_stage_min = 1, -- an unhatched egg never fights
}

local GRAVITY = -9.81

hashimon._guard_off = hashimon._guard_off or {} -- [player_name] = true when opted out
hashimon._mount_fire_held = hashimon._mount_fire_held or {} -- [player_name] = bool

local function now()
	return core.get_us_time() / 1e6
end

local function creature_of(ent)
	if not ent then
		return nil
	end
	return ent.creature or ent.hashimon_creature
end

local function stage_of(ent)
	local creature = creature_of(ent)
	return (hashimon.creature_stage and hashimon.creature_stage(creature)) or 0
end

local function dist3(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--- Is this object one of `owner_name`'s own creatures (or the owner)?
local function is_own_side(owner_name, obj)
	if not obj or not owner_name then
		return false
	end
	if obj:is_player() then
		return obj:get_player_name() == owner_name
	end
	local ent = obj:get_luaentity()
	if not ent then
		return true -- items/carts/unknown: never a target
	end
	if ent.name == "hashimon_entities:element_cube"
		or ent.name == "hashimon_entities:blast_orb"
		or ent.name == "hashimon_entities:voxel_part" then
		return true
	end
	return ent.owner == owner_name
end

function hashimon.guard_enabled_for(player_name)
	return hashimon.GUARD.enabled and not hashimon._guard_off[player_name]
end

--- Give one Hashimon a target. Silently ignored for eggs, mounts in use, and
--- targets on our own side.
function hashimon.set_guard_target(ent, target_obj)
	if not ent or not target_obj or not target_obj:get_pos() then
		return false
	end
	if ent.rider or ent.carried_by then
		return false
	end
	if not ent.owner or not hashimon.guard_enabled_for(ent.owner) then
		return false
	end
	if stage_of(ent) < hashimon.GUARD.guard_stage_min then
		return false
	end
	if is_own_side(ent.owner, target_obj) then
		return false
	end
	ent._guard_target = target_obj
	ent._guard_until = now() + hashimon.GUARD.memory
	ent._follow_active = false
	return true
end

--- Validated target, or nil (and the target is forgotten). Drops on: death,
--- target out of aggro range, guard too far from home, memory expired.
function hashimon.guard_target_for(ent)
	local target = ent and ent._guard_target
	if not target then
		return nil
	end

	local function forget()
		ent._guard_target = nil
		ent._guard_until = nil
		return nil
	end

	if ent.rider or ent.carried_by then
		return forget()
	end
	if (ent._guard_until or 0) < now() then
		return forget()
	end

	local tpos = target:get_pos()
	if not tpos then
		return forget()
	end
	if target:is_player() then
		if target:get_hp() <= 0 then
			return forget()
		end
	else
		local tent = target:get_luaentity()
		if not tent or (tent.hp and tent.hp <= 0) then
			return forget()
		end
	end

	local mypos = ent.object and ent.object:get_pos()
	if not mypos then
		return forget()
	end
	if dist3(mypos, tpos) > hashimon.GUARD.aggro_radius then
		return forget()
	end

	local owner = ent.owner and core.get_player_by_name(ent.owner)
	local opos = owner and owner:get_pos()
	if opos and dist3(mypos, opos) > hashimon.GUARD.leash then
		return forget()
	end

	return target
end

--- Alert every spawned Hashimon of `owner_name` about `attacker_obj`.
--- Returns how many guards took the target.
function hashimon.alert_owner_guards(owner_name, attacker_obj)
	if not owner_name or not attacker_obj then
		return 0
	end
	if not hashimon.guard_enabled_for(owner_name) then
		return 0
	end
	if is_own_side(owner_name, attacker_obj) then
		return 0
	end

	local alerted = 0
	for _, obj in ipairs(hashimon.get_roster_entities(owner_name) or {}) do
		local ent = obj and obj:get_luaentity()
		if ent and hashimon.set_guard_target(ent, attacker_obj) then
			alerted = alerted + 1
		end
	end

	if alerted > 0 then
		local owner = core.get_player_by_name(owner_name)
		local opos = owner and owner:get_pos()
		if opos then
			core.sound_play("default_dug_node", {
				pos = opos,
				max_hear_distance = 24,
				gain = 0.8,
			}, true)
		end
	end
	return alerted
end

--- A Hashimon that gets hit defends itself (and pulls its siblings in).
function hashimon.guard_react_to_punch(ent, puncher)
	if not ent or not puncher or not ent.owner then
		return
	end
	if is_own_side(ent.owner, puncher) then
		return
	end
	hashimon.set_guard_target(ent, puncher)
	hashimon.alert_owner_guards(ent.owner, puncher)
end

function hashimon.guard_melee_damage(creature)
	local stage = (hashimon.creature_stage and hashimon.creature_stage(creature)) or 1
	local mult = math.min(2.4, 1 + stage * 0.045)
	return math.max(1, math.floor(hashimon.GUARD.melee_damage * mult + 0.5))
end

--- Bite. Honours melee_interval per guard.
function hashimon.guard_melee(ent, target)
	if not ent or not target or not target:get_pos() then
		return false
	end
	local t = now()
	if (ent._guard_melee_t or 0) > t then
		return false
	end
	ent._guard_melee_t = t + hashimon.GUARD.melee_interval

	local mypos = ent.object:get_pos()
	local tpos = target:get_pos()
	local dir = vector.normalize(vector.subtract(tpos, mypos))
	local damage = hashimon.guard_melee_damage(creature_of(ent))

	target:punch(ent.object, 1.0, {
		full_punch_interval = 1.0,
		damage_groups = { fleshy = damage },
	}, dir)

	local kb = hashimon.GUARD.melee_knockback
	if kb > 0 and target:get_pos() then
		target:add_velocity({ x = dir.x * kb, y = 2, z = dir.z * kb })
	end
	core.sound_play("default_dug_node", {
		pos = mypos,
		max_hear_distance = 20,
		gain = 0.5,
	}, true)
	return true
end

--- Elemental cube from a guard, aimed at the target's chest.
function hashimon.guard_try_ranged(ent, target)
	if stage_of(ent) < hashimon.GUARD.ranged_stage_min then
		return false
	end
	local mypos = ent.object and ent.object:get_pos()
	local tpos = target and target:get_pos()
	if not mypos or not tpos then
		return false
	end

	local t = now()
	if (ent._guard_ranged_t or 0) > t then
		return false
	end

	-- Aim from the muzzle to the target's chest, not origin-to-origin: a
	-- level shot from a tall body otherwise sails over everything short.
	local muzzle_y = (hashimon.cube_muzzle_height and hashimon.cube_muzzle_height(ent.object))
		or (mypos.y + 0.9)
	local tprops = target.get_properties and target:get_properties()
	local tbox = tprops and tprops.collisionbox
	local chest_y = tpos.y + ((tbox and #tbox >= 6) and (tbox[2] + tbox[5]) * 0.5 or 0.9)
	local aim = {
		x = tpos.x - mypos.x,
		y = chest_y - muzzle_y,
		z = tpos.z - mypos.z,
	}
	local ok = hashimon.launch_element_cube(
		ent.object,
		aim,
		ent.owner,
		creature_of(ent),
		{ no_cooldown = true }
	)
	if ok then
		ent._guard_ranged_t = t + hashimon.GUARD.ranged_cooldown
	end
	return ok and true or false
end

--- Velocity-driven guard step for the sprite and voxel render tiers.
--- Returns true when it took over this tick (caller must skip follow logic).
function hashimon.step_guard(ent, _dtime)
	local target = hashimon.guard_target_for(ent)
	if not target then
		return false
	end

	local mypos = ent.object:get_pos()
	local tpos = target:get_pos()
	local vel = ent.object:get_velocity() or { x = 0, y = 0, z = 0 }
	if not mypos or not tpos then
		return false
	end

	local dx, dz = tpos.x - mypos.x, tpos.z - mypos.z
	local flat = math.sqrt(dx * dx + dz * dz)
	local full = dist3(mypos, tpos)

	-- Face the target (voxel/sprite roots have automatic_face_movement_dir, but
	-- a standing guard still needs to look at what it is biting).
	if flat > 0.05 then
		ent.object:set_yaw(core.dir_to_yaw({ x = dx, y = 0, z = dz }))
	end

	if full <= hashimon.GUARD.melee_range then
		ent.object:set_velocity({ x = 0, y = vel.y, z = 0 })
		hashimon.guard_melee(ent, target)
		return true
	end

	if full >= hashimon.GUARD.ranged_min_range then
		hashimon.guard_try_ranged(ent, target)
	end

	if flat > 0.05 then
		local speed = hashimon.GUARD.approach_speed
		ent.object:set_velocity({
			x = (dx / flat) * speed,
			y = vel.y,
			z = (dz / flat) * speed,
		})
	else
		ent.object:set_velocity({ x = 0, y = vel.y, z = 0 })
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Owner damage → alert
-- ---------------------------------------------------------------------------

core.register_on_punchplayer(function(player, hitter, _time, _tool, _dir, damage)
	if not player or not hitter then
		return
	end
	if damage and damage <= 0 then
		return
	end

	-- Defence: the victim's Hashimons go after whoever hit them.
	hashimon.alert_owner_guards(player:get_player_name(), hitter)

	-- Offence: and what their owner hits, the pack hits too (wolf rules).
	if hitter:is_player() then
		hashimon.alert_owner_guards(hitter:get_player_name(), player)
	end
end)

-- ---------------------------------------------------------------------------
-- Mounted attack: left click throws an elemental cube
-- ---------------------------------------------------------------------------

local function try_mount_fire(player, name)
	local mount_obj = hashimon.mounts and hashimon.mounts[name]
	if not mount_obj or not mount_obj:get_pos() then
		return
	end
	local ent = mount_obj:get_luaentity()
	if not ent then
		return
	end

	local creature = creature_of(ent)
	local ok, info = hashimon.launch_element_cube(
		mount_obj,
		player:get_look_dir(),
		name,
		creature,
		{
			cooldown = hashimon.CUBE_COOLDOWN,
			key = "mount:" .. tostring(
				(hashimon.creature_cooldown_key and hashimon.creature_cooldown_key(creature))
					or name
			),
			element = ent._mount_element_override,
		}
	)

	if ok then
		if not ent._cube_hint_sent then
			ent._cube_hint_sent = true
			local _, elem = hashimon.element_cube_spec(creature, ent._mount_element_override)
			core.chat_send_player(name, string.format(
				"[Hashimon] Clic izquierdo = cubo de %s (cada %.1fs).",
				tostring(elem), hashimon.CUBE_COOLDOWN
			))
		end
		return
	end

	if info == "cooldown" then
		return -- silent; spamming LMB should not spam chat
	end
	if info == "no_creature" then
		core.chat_send_player(name, "[Hashimon] Esta montura no tiene datos de criatura.")
	end
end

core.register_globalstep(function(_dtime)
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		if hashimon.mounts and hashimon.mounts[name] then
			local ctrl = player:get_player_control()
			local held = ctrl.dig and true or false
			local was = hashimon._mount_fire_held[name]
			hashimon._mount_fire_held[name] = held
			if held and not was then
				try_mount_fire(player, name)
			end
		elseif hashimon._mount_fire_held[name] then
			hashimon._mount_fire_held[name] = nil
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Commands (wired from hashimon_core/session.lua: /hashimon guard|fire)
-- ---------------------------------------------------------------------------

--- /hashimon guard [on|off|status|server on|server off]
function hashimon.guard_command(name, rest)
	local sub = (rest:match("^(%S*)") or ""):lower()
	local arg = (rest:match("^%S*%s+(%S*)") or ""):lower()

	if sub == "server" then
		if not core.check_player_privs(name, { server = true }) then
			return false, "Requiere el privilegio server."
		end
		if arg == "on" then
			hashimon.GUARD.enabled = true
			return true, "Defensa de Hashimons: ON (servidor)."
		end
		if arg == "off" then
			hashimon.GUARD.enabled = false
			return true, "Defensa de Hashimons: OFF (servidor)."
		end
		return false, "Uso: /hashimon guard server <on|off>"
	end

	if sub == "on" then
		hashimon._guard_off[name] = nil
		return true, "Tus Hashimons te defenderán."
	end
	if sub == "off" then
		hashimon._guard_off[name] = true
		for _, obj in ipairs(hashimon.get_roster_entities(name) or {}) do
			local ent = obj and obj:get_luaentity()
			if ent then
				ent._guard_target = nil
				ent._guard_until = nil
			end
		end
		return true, "Tus Hashimons ya no te defenderán (pasivos)."
	end

	local guarding = 0
	for _, obj in ipairs(hashimon.get_roster_entities(name) or {}) do
		local ent = obj and obj:get_luaentity()
		if ent and ent._guard_target then
			guarding = guarding + 1
		end
	end
	return true, string.format(
		"Defensa: %s (servidor %s) — %d en combate. Melee desde ★%d, cubos desde ★%d. Uso: /hashimon guard <on|off>",
		hashimon._guard_off[name] and "OFF" or "ON",
		hashimon.GUARD.enabled and "ON" or "OFF",
		guarding,
		hashimon.GUARD.guard_stage_min,
		hashimon.GUARD.ranged_stage_min
	)
end

--- /hashimon fire — throw a cube from the mount (or the nearest Hashimon).
function hashimon.cube_fire_command(name)
	local player = core.get_player_by_name(name)
	if not player then
		return false, "Player not found"
	end

	local dir = player:get_look_dir()
	local mount_obj = hashimon.mounts and hashimon.mounts[name]
	if mount_obj and mount_obj:get_pos() then
		local ent = mount_obj:get_luaentity()
		local ok, info = hashimon.launch_element_cube(mount_obj, dir, name, creature_of(ent), {
			cooldown = hashimon.CUBE_COOLDOWN,
			key = "mount:" .. name,
			element = ent and ent._mount_element_override,
		})
		if ok then
			return true, "Cubo de " .. tostring(info) .. " lanzado."
		end
		if info == "cooldown" then
			return false, string.format("En enfriamiento (%.1fs).",
				hashimon.cube_cooldown_left(name, "mount:" .. name, hashimon.CUBE_COOLDOWN))
		end
		return false, "No se pudo lanzar (" .. tostring(info) .. ")."
	end

	-- Not mounted: nearest spawned Hashimon throws instead.
	local ppos = player:get_pos()
	local best, best_d
	for _, obj in ipairs(hashimon.get_roster_entities(name) or {}) do
		local pos = obj and obj:get_pos()
		if pos then
			local d = dist3(pos, ppos)
			if not best_d or d < best_d then
				best, best_d = obj, d
			end
		end
	end
	if not best then
		return false, "No hay Hashimons cerca. Usa /hashimon sync."
	end

	local ent = best:get_luaentity()
	local ok, info = hashimon.launch_element_cube(best, dir, name, creature_of(ent), {})
	if ok then
		return true, "Cubo de " .. tostring(info) .. " lanzado."
	end
	if info == "cooldown" then
		return false, "En enfriamiento."
	end
	return false, "No se pudo lanzar (" .. tostring(info) .. ")."
end

core.register_on_leaveplayer(function(player)
	hashimon._mount_fire_held[player:get_player_name()] = nil
end)

-- Mount hints live on the Genesis mobility profiles; append the cube line once
-- (aliased profiles share one table, so dedupe by identity).
do
	local seen = {}
	for _, profile in pairs(hashimon.GENESIS_MOBILITY or {}) do
		if type(profile) == "table" and not seen[profile] then
			seen[profile] = true
			if profile.hint and not profile.hint:find("Clic izq") then
				profile.hint = profile.hint .. " Clic izq = cubo elemental."
			end
		end
	end
end

core.log("action", "[hashimon_entities] Guard defense + mounted cube attack registered")

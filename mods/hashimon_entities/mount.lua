-- Riding: once a Hashimon has grown enough (stage-gated), its owner can
-- right-click to mount and steer it.
--
-- Genesis Mobility Law: ability belongs to the creature's element type
-- (type_for_creature), not mesh/morphology. Each Genesis element grants
-- privileged access to one world dimension:
--   aire      → sky (flight)
--   agua      → ocean (swim / dive / breath)
--   tierra    → underground (dig tunnels)
--   electrico → distance (sustained horizontal speed)
--   fuego     → verticality (super jump + glide)

hashimon = hashimon or {}

hashimon.MOUNT_STAGE_THRESHOLD = 10
hashimon.mounts = hashimon.mounts or {} -- [player_name] = mount ObjectRef

local MOUNT_REVERSE_FACTOR = 0.5
local JUMP_DEFAULT = 6.5
local FLY_UP = 4
local FLY_DOWN = 3
local FLY_HOVER = 0.15
local BITS_PER_STAR = 4
local DNA_SIZE_SWING = 0.15 -- ±15% from DNA build/size; never the fantasy
local DIG_INTERVAL = 0.15
local BURROW_SPEED = 6.5
local BURROW_SLOPE = 3.5
local GLIDE_GRAVITY = 0.25
local GLIDE_FORWARD = 1.2
local GRAVITY = -9.81

local BUILD_SPEED = {
	delicate = 1.15, lean = 1.1, balanced = 1.0, stocky = 0.95,
	muscular = 0.92, bulbous = 0.88, angular = 1.05, round = 0.97,
}
local SIZE_SPEED = {
	diminutive = 0.9, small = 0.95, medium = 1.0, large = 1.05, huge = 1.1, massive = 1.15,
}

-- Genesis Mobility profiles. Cruise is nodes/sec; specials use aux1 / jump / sneak.
hashimon.GENESIS_MOBILITY = {
	aire = {
		id = "aire",
		mode = "fly",
		cruise = 7,
		fly_boost = 2.5,
		hint = "Montado (Aire) — WASD, espacio subir, sneak bajar, sprint boost, click derecho para bajar.",
	},
	electrico = {
		id = "electrico",
		mode = "ground",
		cruise = 14,
		sprint = 22,
		jump = JUMP_DEFAULT,
		hint = "Montado (Eléctrico) — WASD, sprint = boost de distancia, click derecho para bajar.",
	},
	["eléctrico"] = nil, -- filled below as alias
	fuego = {
		id = "fuego",
		mode = "ground",
		cruise = 8,
		jump = 16,
		glide = true,
		hint = "Montado (Fuego) — WASD, super salto + planeo, click derecho para bajar.",
	},
	agua = {
		id = "agua",
		mode = "water",
		cruise = 5,
		swim = 12,
		swim_boost = 2.5, -- aux1 → ~30 n/s
		jump = JUMP_DEFAULT,
		hint = "Montado (Agua) — WASD; en agua Sprint/aux1 = hyper-nado; sneak bucear; brilla solo bajo agua; click derecho para bajar.",
	},
	tierra = {
		id = "tierra",
		mode = "ground",
		cruise = 5,
		jump = JUMP_DEFAULT,
		dig = true,
		burrow_speed = BURROW_SPEED,
		hint = "Montado (Tierra) — WASD; MANTÉN Sprint para excavar/túnel (no uses click). Sneak/salto = pendiente. Click derecho para bajar.",
	},
}

hashimon.GENESIS_MOBILITY["eléctrico"] = hashimon.GENESIS_MOBILITY.electrico

local GENERIC_MOBILITY = {
	id = "generic",
	mode = "ground",
	cruise = 6,
	jump = JUMP_DEFAULT,
	hint = "Montado — WASD, espacio saltar, click derecho para bajar.",
}

local ELEMENT_ALIASES = {
	electrico = "electrico",
	["eléctrico"] = "electrico",
	electric = "electrico",
	fuego = "fuego",
	fire = "fuego",
	agua = "agua",
	water = "agua",
	aire = "aire",
	air = "aire",
	tierra = "tierra",
	earth = "tierra",
}

function hashimon.normalize_mount_element(raw)
	if not raw or raw == "" then
		return nil
	end
	local key = tostring(raw):lower():gsub("%s+", "")
	return ELEMENT_ALIASES[key] or (hashimon.GENESIS_MOBILITY[key] and key) or nil
end

function hashimon.creature_from_entity(ent)
	if not ent then
		return nil
	end
	return ent.creature or ent.hashimon_creature
end

--- A creature that has never mined a share is still an egg. Once it has
--- (stars/stage/tier >= 1), it has hatched and shows its full form.
function hashimon.creature_stage(creature)
	return (creature and (creature.stars or creature.stage or creature.tier)) or 0
end

function hashimon.is_rideable(creature)
	return hashimon.creature_stage(creature) >= hashimon.MOUNT_STAGE_THRESHOLD
end

local function dna_speed_mult(creature)
	if not creature or not creature.dna or not hashimon.compile_look then
		return 1.0
	end
	local element_type = hashimon.type_for_creature and hashimon.type_for_creature(creature)
	local look = hashimon.compile_look(creature.dna, element_type)
	if not look then
		return 1.0
	end
	local mult = (BUILD_SPEED[look.build] or 1.0) * (SIZE_SPEED[look.size] or 1.0)
	-- Clamp to ±DNA_SIZE_SWING around 1.0 so DNA never replaces Genesis fantasy.
	local lo, hi = 1.0 - DNA_SIZE_SWING, 1.0 + DNA_SIZE_SWING
	if mult < lo then mult = lo end
	if mult > hi then mult = hi end
	return mult
end

--- Resolve Genesis (or generic) mobility profile for a creature.
--- Optional override_element (QA) wins over DNA type.
function hashimon.mount_profile_for(creature, override_element)
	local elem = hashimon.normalize_mount_element(override_element)
	if not elem and creature and hashimon.type_for_creature then
		elem = hashimon.normalize_mount_element(hashimon.type_for_creature(creature))
	end
	local profile = (elem and hashimon.GENESIS_MOBILITY[elem]) or GENERIC_MOBILITY
	return profile, profile.id
end

--- Flight is Genesis Air only — morphology capabilities do not grant mount flight.
function hashimon.mount_can_fly(ent)
	if not ent then
		return false
	end
	local profile = ent._mount_profile
	if not profile then
		profile = hashimon.mount_profile_for(
			hashimon.creature_from_entity(ent),
			ent._mount_element_override
		)
	end
	return profile and profile.mode == "fly"
end

function hashimon.mount_speed_for(creature, profile)
	profile = profile or hashimon.mount_profile_for(creature)
	local cruise = (profile and profile.cruise) or GENERIC_MOBILITY.cruise
	return cruise * dna_speed_mult(creature)
end

local function seat_for(ent)
	if ent.size_mult then
		return { x = 0, y = 4 * (ent.size_mult or 1.0), z = 0 }
	end
	local props = ent.object and ent.object:get_properties()
	local h = (props and props.visual_size and props.visual_size.y) or 10
	if h >= 5 then
		return { x = 0, y = h * 0.45, z = 0 }
	end
	return { x = 0, y = math.max(8, h * 4), z = 0 }
end

local function clear_water_biolum(ent)
	if not ent or not ent.object then
		return
	end
	ent._water_hyper = nil
	ent._water_fx_t = nil
	ent._water_glow_on = nil
	ent._water_glow_level = nil
	if ent._water_glow_applied then
		local restore = ent._pre_mount_glow or 0
		ent.object:set_properties({ glow = restore })
		ent._water_glow_applied = nil
	end
	ent._pre_mount_glow = nil
end

local function clear_mount_runtime(ent)
	clear_water_biolum(ent)
	ent._mount_profile = nil
	ent._mount_element = nil
	ent._mount_fly = nil
	ent._mount_glide = nil
	ent._mount_dig_t = nil
	ent._mount_burrowing = nil
	ent._burrow_hint_sent = nil
	ent._fire_jumped = nil
	ent.mount_speed = nil
	if ent._pre_mount_acc then
		ent.object:set_acceleration(ent._pre_mount_acc)
		ent._pre_mount_acc = nil
	end
end

--- Try to mount `player` on `mount_obj`. Returns true on success.
function hashimon.mount(player, mount_obj)
	local name = player:get_player_name()
	if hashimon.mounts[name] then
		hashimon.dismount(player)
	end

	local ent = mount_obj:get_luaentity()
	if not ent or ent.rider then
		return false
	end

	local creature = hashimon.creature_from_entity(ent)
	local profile, element = hashimon.mount_profile_for(creature, ent._mount_element_override)
	local can_fly = profile.mode == "fly"

	ent._pre_mount_acc = ent.object:get_acceleration()
	ent._mount_profile = profile
	ent._mount_element = element
	ent._mount_fly = can_fly
	ent._mount_glide = false
	ent._mount_dig_t = 0
	ent._mount_burrowing = false
	ent._burrow_hint_sent = false
	ent._fire_jumped = false
	ent._water_hyper = false
	ent._water_fx_t = 0
	ent._water_glow_on = false
	ent._water_glow_applied = false
	local props0 = ent.object:get_properties()
	ent._pre_mount_glow = (props0 and props0.glow) or 0

	player:set_attach(mount_obj, "", seat_for(ent), { x = 0, y = 0, z = 0 })
	if can_fly then
		player:set_physics_override({ speed = 0, jump = 0, gravity = 0 })
		ent.object:set_acceleration({ x = 0, y = 0, z = 0 })
	else
		player:set_physics_override({ speed = 0, jump = 0 })
		ent.object:set_acceleration({ x = 0, y = GRAVITY, z = 0 })
	end
	player:set_eye_offset({ x = 0, y = 2, z = 0 }, { x = 0, y = 3, z = -4 })

	if ent.memorize then
		ent.order = "stand"
		ent:memorize("order", "stand")
	end

	ent.rider = name
	ent.mount_speed = hashimon.mount_speed_for(creature, profile)
	hashimon.mounts[name] = mount_obj

	core.chat_send_player(name, "[Hashimon] " .. (profile.hint or GENERIC_MOBILITY.hint))
	return true
end

--- Dismount whatever `player` is currently riding, if anything.
function hashimon.dismount(player)
	if not player or not player.get_player_name then
		return false
	end
	local name = player:get_player_name()
	local mount_obj = hashimon.mounts[name]

	player:set_detach()
	player:set_physics_override({ speed = 1, jump = 1, gravity = 1 })
	player:set_eye_offset({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 })

	if mount_obj then
		local ent = mount_obj:get_luaentity()
		if ent and ent.rider == name then
			ent.rider = nil
			clear_mount_runtime(ent)
			-- QA override cleared on dismount so sync/DNA type is authoritative again.
			ent._mount_element_override = nil
			if ent.memorize then
				ent.order = "follow"
				ent:memorize("order", "follow")
			end
		end
	end
	hashimon.mounts[name] = nil

	if mount_obj then
		core.chat_send_player(name, "[Hashimon] Desmontado.")
	end
	return true
end

--- True if this player owns the entity (owner field or roster membership).
function hashimon.player_owns_mount(player_name, ent, owner)
	if not player_name or not ent then
		return false
	end
	if owner and player_name == owner then
		return true
	end
	if ent.owner and player_name == ent.owner then
		return true
	end
	local roster = hashimon.get_roster_entities and hashimon.get_roster_entities(player_name)
	if not roster then
		return false
	end
	local obj = ent.object
	for _, ref in ipairs(roster) do
		if ref == obj then
			return true
		end
	end
	return false
end

--- Owner right-click: dismount, blast, or mount.
--- Always chat why a mount attempt failed so QA is not silent.
function hashimon.try_owner_mount(clicker, obj, creature, owner)
	if not clicker or not clicker:is_player() or not obj then
		return false
	end
	local name = clicker:get_player_name()
	local ent = obj:get_luaentity()
	if not ent then
		return false
	end

	if ent.rider == name then
		hashimon.dismount(clicker)
		return true
	end

	if hashimon.try_shift_blast_attack
		and hashimon.try_shift_blast_attack(clicker, obj, creature, owner)
	then
		return true
	end

	creature = creature or hashimon.creature_from_entity(ent)
	local owns = hashimon.player_owns_mount(name, ent, owner)
	local rideable = hashimon.is_rideable(creature)
	local stage = hashimon.creature_stage(creature)

	if owns and not ent.rider and rideable then
		return hashimon.mount(clicker, obj)
	end

	-- Feedback only for the player's own Hashimon (roster or owner field).
	if owns then
		if ent.rider then
			core.chat_send_player(name, "[Hashimon] Ya tiene jinete.")
		elseif not rideable then
			core.chat_send_player(name, string.format(
				"[Hashimon] Necesita ★%d para montar (ahora ★%d). Usa /hashimon evolve %d",
				hashimon.MOUNT_STAGE_THRESHOLD, stage, hashimon.MOUNT_STAGE_THRESHOLD
			))
		end
	elseif creature then
		core.chat_send_player(name,
			"[Hashimon] Solo el dueño puede montarlo. Prueba /hashimon mount si es tuyo.")
	end
	return false
end

--- Mount the nearest owned roster Hashimon (or one already under override).
--- Used when right-click is awkward (item in hand, small hitbox).
function hashimon.mount_nearest_owned(player)
	if not player or not player:is_player() then
		return false, "no_player"
	end
	local name = player:get_player_name()
	if hashimon.mounts[name] then
		hashimon.dismount(player)
		return true, "dismounted"
	end

	local pos = player:get_pos()
	if not pos then
		return false, "no_pos"
	end

	local best, best_d
	local roster = hashimon.get_roster_entities and hashimon.get_roster_entities(name) or {}
	for _, ref in ipairs(roster) do
		local ent = ref and ref:get_luaentity()
		local rpos = ref and ref:get_pos()
		if ent and rpos and not ent.rider then
			local dx, dy, dz = rpos.x - pos.x, rpos.y - pos.y, rpos.z - pos.z
			local d = dx * dx + dy * dy + dz * dz
			if not best_d or d < best_d then
				best_d = d
				best = ref
			end
		end
	end

	if not best then
		return false, "none_nearby"
	end
	if best_d > 64 then -- >8 nodes
		return false, "too_far"
	end

	local ent = best:get_luaentity()
	local creature = hashimon.creature_from_entity(ent)
	if not hashimon.is_rideable(creature) then
		return false, "not_rideable", hashimon.creature_stage(creature)
	end
	if hashimon.mount(player, best) then
		return true, "mounted"
	end
	return false, "mount_failed"
end

local function movement_forward(control)
	local forward = control.movement_y or 0
	if forward == 0 then
		if control.up then forward = 1
		elseif control.down then forward = -1 end
	end
	return forward
end

local function horizontal_velocity(dir, speed, forward)
	if forward > 0.05 then
		return dir.x * speed * forward, dir.z * speed * forward
	elseif forward < -0.05 then
		local s = speed * MOUNT_REVERSE_FACTOR
		return dir.x * s * forward, dir.z * s * forward
	end
	return 0, 0
end

local function node_is_liquid(pos)
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	return def and def.liquidtype and def.liquidtype ~= "none"
end

local function mount_in_liquid(pos)
	return node_is_liquid(pos)
		or node_is_liquid({ x = pos.x, y = pos.y + 0.8, z = pos.z })
		or node_is_liquid({ x = pos.x, y = pos.y + 1.4, z = pos.z })
end

local function emit_water_light(pos, hyper)
	local amount = hyper and 16 or 10
	local glow = hyper and 14 or 12
	core.add_particlespawner({
		amount = amount,
		time = 0.12,
		minpos = { x = pos.x - 0.5, y = pos.y - 0.3, z = pos.z - 0.5 },
		maxpos = { x = pos.x + 0.5, y = pos.y + 1.4, z = pos.z + 0.5 },
		minvel = { x = -0.15, y = 0.05, z = -0.15 },
		maxvel = { x = 0.15, y = 0.45, z = 0.15 },
		minacc = { x = 0, y = 0, z = 0 },
		maxacc = { x = 0, y = 0.08, z = 0 },
		minexptime = 0.4,
		maxexptime = 1.0,
		minsize = hyper and 2.0 or 1.5,
		maxsize = hyper and 4.0 or 3.2,
		texture = "default_mese_crystal_fragment.png^[colorize:#38BDF8:90",
		glow = glow,
	})
end

local function emit_water_hyper_trail(pos, dir)
	core.add_particlespawner({
		amount = 14,
		time = 0.08,
		minpos = { x = pos.x - 0.3, y = pos.y - 0.2, z = pos.z - 0.3 },
		maxpos = { x = pos.x + 0.3, y = pos.y + 1.0, z = pos.z + 0.3 },
		minvel = { x = -dir.x * 4 - 0.4, y = -0.2, z = -dir.z * 4 - 0.4 },
		maxvel = { x = -dir.x * 7 + 0.4, y = 0.6, z = -dir.z * 7 + 0.4 },
		minacc = { x = 0, y = 0, z = 0 },
		maxacc = { x = 0, y = 0.1, z = 0 },
		minexptime = 0.25,
		maxexptime = 0.55,
		minsize = 1.8,
		maxsize = 3.5,
		texture = "default_mese_crystal_fragment.png^[colorize:#7DD3FC:120",
		glow = 14,
	})
end

local WATER_GLOW_CRUISE = 8
local WATER_GLOW_HYPER = 14

local function set_water_biolum(self, active, hyper)
	if not self or not self.object then
		return
	end
	if active then
		local want = hyper and WATER_GLOW_HYPER or WATER_GLOW_CRUISE
		if not self._water_glow_applied or self._water_glow_level ~= want then
			if self._pre_mount_glow == nil then
				local props = self.object:get_properties()
				self._pre_mount_glow = (props and props.glow) or 0
			end
			self.object:set_properties({ glow = want })
			self._water_glow_applied = true
			self._water_glow_level = want
		end
		self._water_glow_on = true
	elseif self._water_glow_on or self._water_glow_applied then
		local restore = self._pre_mount_glow or 0
		self.object:set_properties({ glow = restore })
		self._water_glow_on = false
		self._water_glow_applied = false
		self._water_glow_level = nil
	end
end

local function tunnel_extents(self)
	local props = self.object:get_properties()
	local box = props and props.collisionbox
	local half_w, half_h, half_d = 1.5, 1.5, 1.5
	if box and #box >= 6 then
		half_w = math.max(1.5, math.ceil(math.max(math.abs(box[1]), math.abs(box[4]))))
		half_h = math.max(1.5, math.ceil(math.max(0.5, box[5] - box[2]) / 2))
		half_d = math.max(1.5, math.ceil(math.max(math.abs(box[3]), math.abs(box[6]))))
	end
	-- Cap so one tick does not melt the whole map on a huge paleo body.
	half_w = math.min(half_w, 4)
	half_h = math.min(half_h, 4)
	half_d = math.min(half_d, 4)
	return half_w, half_h, half_d
end

local function can_burrow_node(nodename, def)
	if not def or nodename == "air" or nodename == "ignore" then
		return false
	end
	if def.liquidtype and def.liquidtype ~= "none" then
		return false
	end
	if def.diggable == false then
		return false
	end
	if core.get_item_group(nodename, "unbreakable") > 0 then
		return false
	end
	if core.get_item_group(nodename, "immortal") > 0 then
		return false
	end
	return true
end

local function try_burrow_remove(dig_pos, pname, rider)
	local node = core.get_node(dig_pos)
	if node.name == "air" or node.name == "ignore" then
		return false
	end
	local def = core.registered_nodes[node.name]
	if not can_burrow_node(node.name, def) then
		return false
	end
	if core.is_protected(dig_pos, pname) then
		return false
	end
	local drops = core.get_node_drops(node, "")
	core.remove_node(dig_pos)
	if drops and #drops > 0 and core.handle_node_drops then
		core.handle_node_drops(dig_pos, drops, rider)
	end
	return true
end

local function emit_burrow_dust(pos, amount)
	amount = math.min(amount or 6, 18)
	core.add_particlespawner({
		amount = amount,
		time = 0.12,
		minpos = { x = pos.x - 0.8, y = pos.y - 0.2, z = pos.z - 0.8 },
		maxpos = { x = pos.x + 0.8, y = pos.y + 1.5, z = pos.z + 0.8 },
		minvel = { x = -0.5, y = 0.1, z = -0.5 },
		maxvel = { x = 0.5, y = 1.2, z = 0.5 },
		minacc = { x = 0, y = -2, z = 0 },
		maxacc = { x = 0, y = -4, z = 0 },
		minexptime = 0.3,
		maxexptime = 0.7,
		minsize = 1.5,
		maxsize = 3.5,
		texture = "default_dirt.png",
		glow = 0,
	})
end

--- Dig a tunnel sized to the mount collisionbox. Uses remove_node (not dig_node)
--- so bare hands never fail the carve. Never places nodes (no rails).
function hashimon.mount_dig_tunnel(self, rider, dir, dtime, slope_y)
	self._mount_dig_t = (self._mount_dig_t or 0) + dtime
	if self._mount_dig_t < DIG_INTERVAL then
		return 0
	end
	self._mount_dig_t = 0

	local pos = self.object:get_pos()
	if not pos then
		return 0
	end
	local name = rider:get_player_name()
	local half_w, half_h, half_d = tunnel_extents(self)

	local dx, dy, dz = dir.x, slope_y or 0, dir.z
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	if len < 0.01 then
		dx, dy, dz = 1, 0, 0
		len = 1
	end
	dx, dy, dz = dx / len, dy / len, dz / len

	local px, pz = -dz, dx
	local plen = math.sqrt(px * px + pz * pz)
	if plen > 0.01 then
		px, pz = px / plen, pz / plen
	else
		px, pz = 1, 0
	end

	local dug = 0
	local max_dug = 64
	local ahead_steps = math.max(2, math.ceil(half_d * 2 + 2))
	for step = 0, ahead_steps do
		local cx = pos.x + dx * step
		local cy = pos.y + dy * step
		local cz = pos.z + dz * step
		for wi = -half_w, half_w do
			for hi = 0, half_h * 2 do
				if dug >= max_dug then
					emit_burrow_dust(pos, dug)
					return dug
				end
				local dig_pos = {
					x = math.floor(cx + px * wi + 0.5),
					y = math.floor(cy - 0.2 + hi + 0.5),
					z = math.floor(cz + pz * wi + 0.5),
				}
				if try_burrow_remove(dig_pos, name, rider) then
					dug = dug + 1
				end
			end
		end
	end
	if dug > 0 then
		emit_burrow_dust(pos, dug)
	end
	return dug
end

local function set_burrow_physics(self, rider, active)
	if active then
		rider:set_physics_override({ speed = 0, jump = 0, gravity = 0 })
		self.object:set_acceleration({ x = 0, y = 0, z = 0 })
		self._mount_burrowing = true
	else
		rider:set_physics_override({ speed = 0, jump = 0, gravity = 1 })
		self.object:set_acceleration({ x = 0, y = GRAVITY, z = 0 })
		self._mount_burrowing = false
	end
end

--- Apply a local Genesis element override for QA (or clear with nil).
function hashimon.set_mount_element_override(ent, element)
	if not ent then
		return false, "no_entity"
	end
	if element == nil or element == "" or element == "clear" or element == "reset" then
		ent._mount_element_override = nil
	else
		local norm = hashimon.normalize_mount_element(element)
		if not norm then
			return false, "invalid_element"
		end
		ent._mount_element_override = norm
	end

	local creature = hashimon.creature_from_entity(ent)
	local profile, id = hashimon.mount_profile_for(creature, ent._mount_element_override)
	ent._mount_profile = profile
	ent._mount_element = id
	ent._mount_fly = profile.mode == "fly"
	ent.mount_speed = hashimon.mount_speed_for(creature, profile)
	ent._mount_glide = false
	ent._fire_jumped = false

	if ent.rider then
		local rider = core.get_player_by_name(ent.rider)
		if rider then
			if profile.mode == "fly" then
				rider:set_physics_override({ speed = 0, jump = 0, gravity = 0 })
				ent.object:set_acceleration({ x = 0, y = 0, z = 0 })
			else
				rider:set_physics_override({ speed = 0, jump = 0, gravity = 1 })
				ent.object:set_acceleration({ x = 0, y = GRAVITY, z = 0 })
			end
		end
	end
	return true, id
end

--- Called from a mount's on_step whenever self.rider is set.
function hashimon.step_mounted(self, dtime)
	dtime = dtime or 0.05
	local rider_obj = core.get_player_by_name(self.rider)
	local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }

	if not rider_obj or not rider_obj:is_player() then
		self.rider = nil
		clear_mount_runtime(self)
		self.object:set_velocity({ x = 0, y = vel.y, z = 0 })
		return
	end

	local creature = hashimon.creature_from_entity(self)
	local profile = self._mount_profile
	if not profile then
		profile = hashimon.mount_profile_for(creature, self._mount_element_override)
		self._mount_profile = profile
		self._mount_element = profile.id
	end

	local yaw = rider_obj:get_look_horizontal()
	self.object:set_yaw(yaw)

	local control = rider_obj:get_player_control()
	local dir = core.yaw_to_dir(yaw)
	local forward = movement_forward(control)
	local cruise = self.mount_speed or hashimon.mount_speed_for(creature, profile)
	local speed = cruise
	local mode = profile.mode or "ground"

	local pos = self.object:get_pos() or { x = 0, y = 0, z = 0 }
	local in_liquid = mount_in_liquid(pos)

	-- --- Water: swim / hyper-nado + breath + auto biolum ---
	local water_hyper = false
	if mode == "water" and in_liquid then
		local base_swim = (profile.swim or 12) * dna_speed_mult(creature)
		water_hyper = control.aux1 and true or false
		self._water_hyper = water_hyper
		if water_hyper then
			speed = base_swim * (profile.swim_boost or 2.5)
		else
			speed = base_swim
		end
		local props = rider_obj:get_properties()
		local breath_max = (props and props.breath_max) or 11
		if breath_max < 1 then breath_max = 11 end
		rider_obj:set_breath(breath_max)

		set_water_biolum(self, true, water_hyper)
		local fx_interval = water_hyper and 0.12 or 0.25
		self._water_fx_t = (self._water_fx_t or 0) + dtime
		if self._water_fx_t >= fx_interval then
			self._water_fx_t = 0
			emit_water_light(pos, water_hyper)
			if water_hyper then
				emit_water_hyper_trail(pos, dir)
			end
		end
	elseif mode == "water" then
		self._water_hyper = false
		set_water_biolum(self, false, false)
	elseif self._water_glow_applied then
		-- Left Agua profile (e.g. QA element swap) — drop biolum.
		self._water_hyper = false
		set_water_biolum(self, false, false)
	end

	-- --- Electric: sustained sprint ---
	if mode == "ground" and profile.sprint and control.aux1 then
		speed = profile.sprint * dna_speed_mult(creature)
	end

	-- --- Air: flight boost ---
	local boost = 1
	if mode == "fly" and control.aux1 then
		boost = profile.fly_boost or 2.5
		speed = cruise * boost
	end

	local vx, vz = horizontal_velocity(dir, speed, forward)
	local vy = vel.y

	-- --- Tierra burrow: hold aux1 to carve + travel underground ---
	if profile.dig and control.aux1 then
		if not self._burrow_hint_sent then
			self._burrow_hint_sent = true
			core.chat_send_player(self.rider,
				"[Hashimon] Excavar = mantener Sprint (no click). El click coloca el ítem del hotbar.")
		end
		if not self._mount_burrowing then
			set_burrow_physics(self, rider_obj, true)
		end

		local slope = 0
		if control.sneak then
			slope = -0.55
		elseif control.jump then
			slope = 0.45
		end
		hashimon.mount_dig_tunnel(self, rider_obj, dir, dtime, slope)

		local burrow = (profile.burrow_speed or BURROW_SPEED) * dna_speed_mult(creature)
		-- Always push forward while burrowing so you enter the tunnel even if idle.
		local move = forward
		if math.abs(move) < 0.05 then
			move = 1
		end
		vx, vz = horizontal_velocity(dir, burrow, move)
		if control.sneak then
			vy = -BURROW_SLOPE
		elseif control.jump then
			vy = BURROW_SLOPE
		else
			vy = 0
		end
		self.object:set_velocity({ x = vx, y = vy, z = vz })
		return
	elseif profile.dig and self._mount_burrowing then
		set_burrow_physics(self, rider_obj, false)
	end

	if mode == "fly" then
		if control.jump then
			vy = FLY_UP * boost
		elseif control.sneak then
			vy = -FLY_DOWN * boost
		elseif math.abs(vx) + math.abs(vz) < 0.01 then
			vy = FLY_HOVER
		else
			vy = math.max(vy * 0.9, FLY_HOVER)
		end
	elseif mode == "water" and in_liquid then
		-- Neutral buoyancy while submerged; sneak dives, jump rises.
		-- Hyper scales vertical motion ~1.4× so boost feels 3D.
		local v_mult = water_hyper and 1.4 or 1.0
		if control.sneak then
			vy = -6 * v_mult
		elseif control.jump then
			vy = 5 * v_mult
		else
			vy = vy * 0.85
			if math.abs(vy) < 0.15 then
				vy = 0
			end
		end
		self.object:set_acceleration({ x = 0, y = 0, z = 0 })
	else
		-- Ground (fire / electric / earth surface / generic / water-on-land)
		if not in_liquid then
			self.object:set_acceleration({ x = 0, y = GRAVITY, z = 0 })
		end

		local jump_v = profile.jump or JUMP_DEFAULT
		local on_ground = math.abs(vel.y) < 0.08

		if profile.glide then
			-- Fire: super jump, then glide after apex until landing.
			if control.jump and on_ground and not self._fire_jumped then
				vy = jump_v
				self._fire_jumped = true
				self._mount_glide = false
			elseif self._fire_jumped then
				if vel.y <= 0.4 then
					self._mount_glide = true
				end
				if self._mount_glide then
					if vy < -GLIDE_GRAVITY * 12 then
						vy = -GLIDE_GRAVITY * 12
					end
					vy = vy * 0.92
					if math.abs(vx) + math.abs(vz) < 0.05 and forward >= 0 then
						vx = dir.x * cruise * 0.35 * GLIDE_FORWARD
						vz = dir.z * cruise * 0.35 * GLIDE_FORWARD
					end
				end
				if on_ground and vel.y <= 0.05 then
					self._fire_jumped = false
					self._mount_glide = false
				end
			elseif control.jump and on_ground then
				vy = jump_v
			end
		else
			if control.jump and on_ground then
				vy = jump_v
			end
		end
	end

	self.object:set_velocity({ x = vx, y = vy, z = vz })
end

--- Local-only star bump for QA. Does not write the API / ledger.
function hashimon.apply_local_stars(creature, stars)
	if not creature or not stars then
		return
	end
	creature.stars = stars
	creature.stage = stars
	creature.tier = stars
	creature.bits = stars * BITS_PER_STAR
	creature.pow = creature.pow or {}
	creature.pow.bestShareBits = stars * BITS_PER_STAR
end

core.register_on_leaveplayer(function(player)
	hashimon.dismount(player)
end)

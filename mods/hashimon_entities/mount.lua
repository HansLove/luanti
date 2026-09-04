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
		fly_boost = 3,
		skyrocket_up = 80,
		skyrocket_max_t = 3.0,
		skyrocket_cd = 8.0,
		dive_down = 80,
		dive_max_t = 3.0,
		dive_cd = 8.0,
		hint = "Montado (Aire) — WASD; Sprint = hyper; Space+Sprint = cohete; Sneak+Sprint = picada meteorito (impacto = boom); click derecho para bajar.",
	},
	electrico = {
		id = "electrico",
		mode = "ground",
		cruise = 14,
		sprint = 22,
		jump = JUMP_DEFAULT,
		arc_bolt = true, -- Jump+Sprint = parabolic thunder → blink on land
		arc_bolt_cd = 2.5,
		hint = "Montado (Eléctrico) — WASD; Sprint = velocidad; Salto+Sprint = rayo al cielo (blink al aterrizar); mira arriba/horizonte; click derecho para bajar.",
	},
	["eléctrico"] = nil, -- filled below as alias
	fuego = {
		id = "fuego",
		mode = "ground",
		cruise = 8,
		jump = 16,
		glide = true,
		propel = 22, -- hold aux1 horizontal speed
		propel_air = 26, -- mid-air aux1 (leap thrust)
		hint = "Montado (Fuego) — WASD; salto = salto potente; mantén Sprint/aux1 = propulsión (fuego, no vuelo); click derecho para bajar.",
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

-- Rider attach + camera. Per-body mount_view on body_def overrides; else derived
-- from collisionbox height. Bone priority: mount_view.bone > Socket.Mount >
-- bones.torso > "" (entity origin). Sam sit pose via player_api when available.
hashimon._saved_rider_props = hashimon._saved_rider_props or {}

local function vec3_or(v, fallback)
	if type(v) == "table" and type(v.x) == "number" then
		return v
	end
	return fallback
end

--- Resolve body_id from a mounted entity (Creatura morph, villain, or DNA compile).
function hashimon.body_id_from_entity(ent)
	if not ent then
		return nil
	end
	if ent.body_id then
		return ent.body_id
	end
	if ent.hashimon_morph and ent.hashimon_morph.body_id then
		return ent.hashimon_morph.body_id
	end
	local creature = hashimon.creature_from_entity(ent)
	if creature and hashimon.compile_morphology then
		local morph = hashimon.compile_morphology(creature)
		if morph and morph.body_id then
			return morph.body_id
		end
	end
	return nil
end

local function collision_height_for(ent)
	local props = ent.object and ent.object:get_properties()
	local box = props and props.collisionbox
	if box and #box >= 5 then
		return box[5] - box[2]
	end
	local body_id = hashimon.body_id_from_entity(ent)
	local body = body_id and hashimon.get_body and hashimon.get_body(body_id)
	if body and body.hitbox and body.hitbox.height then
		return body.hitbox.height
	end
	return 1.0
end

local function mount_bone_for(body, custom)
	local raw
	if custom and custom.bone and custom.bone ~= "" then
		raw = custom.bone
	elseif body and body.bones then
		if body.bones.mount_socket then
			raw = body.bones.mount_socket
		elseif body.bones.torso then
			raw = body.bones.torso
		end
	end
	if not raw or raw == "" then
		return ""
	end
	-- Creatures use Hashimon names; resolve_bone is identity for "hashimon"
	-- and accepts Socket.Mount / Torso / Arm.L as authored.
	if hashimon.resolve_bone then
		return hashimon.resolve_bone(raw, "hashimon")
	end
	return raw
end

--- Default rider seat + camera when body_def.mount_view is absent.
function hashimon.default_mount_view(ent, profile)
	local height = collision_height_for(ent)
	local can_fly = profile and profile.mode == "fly"

	local seat_y
	if ent.size_mult then
		seat_y = 4 * (ent.size_mult or 1.0)
	else
		seat_y = math.max(8, height * 4)
	end

	local eye_y = math.max(2, height * 8)
	local eye_z = can_fly and 4 or 1
	local third_y = math.min(15, eye_y + 4)
	local third_z = can_fly and -8 or -5

	return {
		bone = "",
		seat = { x = 0, y = seat_y, z = 0 },
		rot = { x = 0, y = 0, z = 0 },
		eye_first = { x = 0, y = eye_y, z = eye_z },
		eye_third = { x = 0, y = third_y, z = third_z },
		hide_rider = false,
		forced_visible = false,
		rider_scale = nil,
		suggest_camera = nil,
	}
end

--- Merge body_def.mount_view with collisionbox-derived defaults.
function hashimon.resolve_mount_view(ent, profile)
	local body_id = hashimon.body_id_from_entity(ent)
	local body = body_id and hashimon.get_body and hashimon.get_body(body_id)
	local custom = body and body.mount_view
	local defaults = hashimon.default_mount_view(ent, profile)

	if not custom then
		defaults.bone = mount_bone_for(body, nil)
		return defaults
	end

	local scale = custom.rider_scale
	if type(scale) ~= "number" or scale <= 0 then
		scale = nil
	end
	-- suggest_camera (alias: prefer_camera) — hint only; does not lock C key.
	local cam = custom.suggest_camera or custom.prefer_camera
	if cam ~= "third" and cam ~= "first" and cam ~= "any" then
		cam = nil
	end

	return {
		bone = mount_bone_for(body, custom),
		seat = vec3_or(custom.seat, defaults.seat),
		rot = vec3_or(custom.rot, defaults.rot),
		eye_first = vec3_or(custom.eye_first, defaults.eye_first),
		eye_third = vec3_or(custom.eye_third, defaults.eye_third),
		hide_rider = custom.hide_rider == true,
		forced_visible = custom.forced_visible == true,
		rider_scale = scale,
		suggest_camera = cam,
	}
end

local function set_rider_attached(player, attached)
	local name = player:get_player_name()
	if player_api then
		player_api.player_attached = player_api.player_attached or {}
		if attached then
			player_api.player_attached[name] = true
		else
			player_api.player_attached[name] = nil
		end
	end
end

local function set_rider_animation(player, anim)
	if player_api and player_api.set_animation then
		player_api.set_animation(player, anim)
	elseif player.set_animation then
		local ranges = {
			sit = { x = 81, y = 160 },
			stand = { x = 0, y = 79 },
		}
		local r = ranges[anim]
		if r then
			player:set_animation(r, 30, 0, true)
		end
	end
end

local function save_rider_props(player)
	local name = player:get_player_name()
	if hashimon._saved_rider_props[name] then
		return
	end
	local props = player:get_properties()
	hashimon._saved_rider_props[name] = {
		pointable = props.pointable,
		visual_size = props.visual_size,
	}
end

--- Shrink Sam to nearly invisible (MIT dragons that still clip).
local function hide_rider(player)
	save_rider_props(player)
	player:set_properties({
		pointable = false,
		visual_size = { x = 0.001, y = 0.001 },
	})
end

--- Scale Sam to sit proportionally on a Hashimon (Ark-style visible rider).
---
--- CRITICAL: Luanti multiplies child visual_size by the parent's when attached
--- (Irrlicht scene-graph). A stage-13 road_adult has visual_size ≈ 3, so
--- rider_scale 0.45 without compensation renders Sam at ~1.3× — giant on the
--- saddle. Divide by the mount's visual_size so `rider_scale` means "fraction
--- of unmounted Sam height in world space".
local function scale_rider(player, scale, mount_obj)
	if type(scale) ~= "number" or scale <= 0 then
		return
	end
	save_rider_props(player)
	local saved = hashimon._saved_rider_props[player:get_player_name()]
	local base = saved and saved.visual_size or { x = 1, y = 1 }
	local bx = (type(base) == "table" and base.x) or 1
	local by = (type(base) == "table" and base.y) or bx
	local bz = (type(base) == "table" and base.z) or bx

	local parent_vs = 1
	if mount_obj and mount_obj.get_properties then
		local mp = mount_obj:get_properties()
		local pvs = mp and mp.visual_size
		if type(pvs) == "table" and type(pvs.x) == "number" and pvs.x > 0.001 then
			parent_vs = pvs.x
		end
	end
	local factor = scale / parent_vs

	player:set_properties({
		visual_size = { x = bx * factor, y = by * factor, z = bz * factor },
	})
end

local function restore_rider(player)
	local name = player:get_player_name()
	local saved = hashimon._saved_rider_props[name]
	if saved then
		player:set_properties({
			pointable = saved.pointable,
			visual_size = saved.visual_size,
		})
		hashimon._saved_rider_props[name] = nil
	end
end

local function unlock_camera(player)
	if not player or not player.set_camera then
		return
	end
	player:set_camera({ mode = "any" })
end

local function reset_camera(player)
	if not player or not player.set_camera then
		return
	end
	player:set_camera(nil)
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
	ent._mount_fly_boost = nil
	ent._mount_glide = nil
	ent._mount_dig_t = nil
	ent._mount_burrowing = nil
	ent._burrow_hint_sent = nil
	ent._fire_jumped = nil
	ent._fire_fx_t = nil
	ent._fire_propelling = nil
	ent._air_fx_t = nil
	ent._jump_was_down = nil
	ent._arc_bolt_obj = nil
	ent._arc_bolt_look = nil
	ent._arc_bolt_surge_t = nil
	ent._mount_run_boost = nil
	ent._arc_dash_cd = nil
	ent._arc_dash_hint_sent = nil
	ent._arc_dash_glow_t = nil
	if ent._arc_glow_applied then
		local restore = ent._pre_mount_glow or 0
		ent.object:set_properties({ glow = restore })
		ent._arc_glow_applied = nil
	end
	ent._skyrocket_cd = nil
	ent._skyrocket_t = nil
	ent._skyrocket_active = nil
	ent._skyrocket_start_y = nil
	ent._dive_cd = nil
	ent._dive_t = nil
	ent._dive_active = nil
	ent._dive_start_y = nil
	ent._meteor_armed = nil
	ent._meteor_peak = nil
	ent.mount_speed = nil
	ent._anim_fly_hold = nil
	-- Restore Creatura AI / gravity that we suspended while ridden.
	if ent._pre_mount_utility_stack then
		ent.utility_stack = ent._pre_mount_utility_stack
		ent._pre_mount_utility_stack = nil
	end
	if ent.set_gravity then
		ent:set_gravity(-9.8)
	end
	if ent._pre_mount_acc then
		ent.object:set_acceleration(ent._pre_mount_acc)
		ent._pre_mount_acc = nil
	end
end

--- Creatura's `_physics` re-applies `_movement_data.gravity` every tick and can
--- run idle/follow actions before `step_func`. That fights fly mounts (accel -9.8
--- + halt) and causes a visible "tic". Suspend AI and zero Creatura gravity.
local function suspend_creatura_while_mounted(ent, can_fly)
	if not ent then
		return
	end
	if not ent._pre_mount_utility_stack then
		ent._pre_mount_utility_stack = ent.utility_stack
	end
	ent.utility_stack = {}
	if ent.clear_utility then
		ent:clear_utility()
	end
	if ent.clear_action then
		ent:clear_action()
	end
	if ent.halt then
		ent:halt()
	end
	if can_fly and ent.set_gravity then
		ent:set_gravity(0)
	elseif ent.set_gravity then
		ent:set_gravity(-9.8)
	end
end

--- Try to mount `player` on `mount_obj`. Returns true on success.
function hashimon.mount(player, mount_obj)
	local name = player:get_player_name()
	if hashimon.carries and hashimon.carries[name] then
		core.chat_send_player(name, "[Hashimon] Suelta el baby primero (/hashimon carry off).")
		return false
	end
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
	ent._mount_fly_boost = false
	ent._mount_glide = false
	ent._mount_dig_t = 0
	ent._mount_burrowing = false
	ent._burrow_hint_sent = false
	ent._fire_jumped = false
	ent._fire_fx_t = 0
	ent._fire_propelling = false
	ent._jump_was_down = false
	ent._arc_bolt_obj = nil
	ent._arc_bolt_look = nil
	ent._arc_bolt_surge_t = 0
	ent._mount_run_boost = false
	ent._arc_dash_cd = 0
	ent._arc_dash_hint_sent = false
	ent._arc_dash_glow_t = 0
	ent._arc_glow_applied = false
	ent._skyrocket_cd = 0
	ent._skyrocket_t = 0
	ent._skyrocket_active = false
	ent._skyrocket_start_y = nil
	ent._dive_cd = 0
	ent._dive_t = 0
	ent._dive_active = false
	ent._dive_start_y = nil
	ent._meteor_armed = false
	ent._meteor_peak = 0
	ent._water_hyper = false
	ent._water_fx_t = 0
	ent._water_glow_on = false
	ent._water_glow_applied = false
	local props0 = ent.object:get_properties()
	ent._pre_mount_glow = (props0 and props0.glow) or 0

	local view = hashimon.resolve_mount_view(ent, profile)
	ent._mount_view = view

	if hashimon.attach_to_socket then
		hashimon.attach_to_socket(
			mount_obj, view.bone, player, view.seat, view.rot, "hashimon", view.forced_visible
		)
	else
		player:set_attach(mount_obj, view.bone, view.seat, view.rot, view.forced_visible == true)
	end
	if can_fly then
		player:set_physics_override({ speed = 0, jump = 0, gravity = 0 })
		ent.object:set_acceleration({ x = 0, y = 0, z = 0 })
	else
		player:set_physics_override({ speed = 0, jump = 0 })
		ent.object:set_acceleration({ x = 0, y = GRAVITY, z = 0 })
	end
	suspend_creatura_while_mounted(ent, can_fly)
	player:set_eye_offset(view.eye_first, view.eye_third)
	set_rider_attached(player, true)
	set_rider_animation(player, "sit")
	if view.hide_rider then
		hide_rider(player)
	elseif view.rider_scale then
		scale_rider(player, view.rider_scale, mount_obj)
	end
	unlock_camera(player)

	if ent.memorize then
		ent.order = "stand"
		ent:memorize("order", "stand")
	end

	ent.rider = name
	ent.mount_speed = hashimon.mount_speed_for(creature, profile)
	hashimon.mounts[name] = mount_obj

	core.chat_send_player(name, "[Hashimon] " .. (profile.hint or GENERIC_MOBILITY.hint))
	if view.suggest_camera == "third" then
		core.chat_send_player(name,
			"[Hashimon] Vista 3ª recomendada (estilo Ark). Pulsa C para cambiar.")
	end
	return true
end

--- Re-apply seat / eyes on the current mount without remounting (live calibration).
--- @param player ObjectRef
--- @param patch table|nil keys: eye_first, eye_third, seat, rot (partial ok)
--- @return boolean, string|nil ok, err
function hashimon.apply_mount_view_patch(player, patch)
	if not player or not player.get_player_name then
		return false, "no_player"
	end
	local name = player:get_player_name()
	local mount_obj = hashimon.mounts and hashimon.mounts[name]
	if not mount_obj then
		return false, "not_mounted"
	end
	local ent = mount_obj:get_luaentity()
	if not ent or ent.rider ~= name then
		return false, "not_mounted"
	end

	local view = ent._mount_view
	if not view then
		local profile = ent._mount_profile or hashimon.mount_profile_for(hashimon.creature_from_entity(ent))
		view = hashimon.resolve_mount_view(ent, profile)
	end

	patch = patch or {}
	if patch.eye_first then
		view.eye_first = vec3_or(patch.eye_first, view.eye_first)
	end
	if patch.eye_third then
		view.eye_third = vec3_or(patch.eye_third, view.eye_third)
	end
	if patch.seat then
		view.seat = vec3_or(patch.seat, view.seat)
	end
	if patch.rot then
		view.rot = vec3_or(patch.rot, view.rot)
	end
	ent._mount_view = view

	if hashimon.attach_to_socket then
		hashimon.attach_to_socket(
			mount_obj, view.bone, player, view.seat, view.rot, "hashimon", view.forced_visible
		)
	else
		player:set_attach(mount_obj, view.bone, view.seat, view.rot, view.forced_visible == true)
	end
	player:set_eye_offset(view.eye_first, view.eye_third)
	set_rider_animation(player, "sit")
	if view.hide_rider then
		hide_rider(player)
	elseif view.rider_scale then
		scale_rider(player, view.rider_scale, mount_obj)
	end
	return true, view
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
	reset_camera(player)
	set_rider_attached(player, false)
	set_rider_animation(player, "stand")
	restore_rider(player)

	if mount_obj then
		local ent = mount_obj:get_luaentity()
		if ent and ent.rider == name then
			if hashimon.clear_arc_bolt then
				hashimon.clear_arc_bolt(name)
			end
			ent.rider = nil
			ent._mount_view = nil
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

local function emit_fire_trail(pos, dir)
	core.add_particlespawner({
		amount = 18,
		time = 0.1,
		minpos = { x = pos.x - 0.4, y = pos.y - 0.1, z = pos.z - 0.4 },
		maxpos = { x = pos.x + 0.4, y = pos.y + 0.8, z = pos.z + 0.4 },
		minvel = { x = -dir.x * 3 - 0.5, y = 0.2, z = -dir.z * 3 - 0.5 },
		maxvel = { x = -dir.x * 6 + 0.5, y = 2.2, z = -dir.z * 6 + 0.5 },
		minacc = { x = 0, y = 1, z = 0 },
		maxacc = { x = 0, y = 3, z = 0 },
		minexptime = 0.2,
		maxexptime = 0.45,
		minsize = 1.5,
		maxsize = 3.5,
		texture = "default_mese_crystal_fragment.png^[colorize:#F97316:160",
		glow = 12,
	})
	core.add_particlespawner({
		amount = 8,
		time = 0.08,
		minpos = { x = pos.x - 0.25, y = pos.y - 0.05, z = pos.z - 0.25 },
		maxpos = { x = pos.x + 0.25, y = pos.y + 0.4, z = pos.z + 0.25 },
		minvel = { x = -dir.x * 2 - 0.3, y = 0.5, z = -dir.z * 2 - 0.3 },
		maxvel = { x = -dir.x * 4 + 0.3, y = 1.8, z = -dir.z * 4 + 0.3 },
		minacc = { x = 0, y = 0.5, z = 0 },
		maxacc = { x = 0, y = 2, z = 0 },
		minexptime = 0.15,
		maxexptime = 0.35,
		minsize = 1.0,
		maxsize = 2.2,
		texture = "default_mese_crystal_fragment.png^[colorize:#FDE68A:140",
		glow = 14,
	})
end

local function emit_electric_arc_trail(from, to)
	local mid = {
		x = (from.x + to.x) * 0.5,
		y = (from.y + to.y) * 0.5 + 0.4,
		z = (from.z + to.z) * 0.5,
	}
	local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
	core.add_particlespawner({
		amount = 28,
		time = 0.12,
		minpos = {
			x = math.min(from.x, to.x) - 0.3,
			y = math.min(from.y, to.y) - 0.2,
			z = math.min(from.z, to.z) - 0.3,
		},
		maxpos = {
			x = math.max(from.x, to.x) + 0.3,
			y = math.max(from.y, to.y) + 1.2,
			z = math.max(from.z, to.z) + 0.3,
		},
		minvel = { x = -0.5, y = -0.2, z = -0.5 },
		maxvel = { x = 0.5, y = 1.2, z = 0.5 },
		minexptime = 0.15,
		maxexptime = 0.4,
		minsize = 1.2,
		maxsize = 3.0,
		texture = "default_mese_crystal_fragment.png^[colorize:#FDE047:170",
		glow = 14,
	})
	core.add_particlespawner({
		amount = 12,
		time = 0.08,
		minpos = { x = mid.x - 0.4, y = mid.y - 0.3, z = mid.z - 0.4 },
		maxpos = { x = mid.x + 0.4, y = mid.y + 0.8, z = mid.z + 0.4 },
		minvel = { x = dx * 0.4 - 0.3, y = dy * 0.4, z = dz * 0.4 - 0.3 },
		maxvel = { x = dx * 1.2 + 0.3, y = dy * 1.2 + 0.5, z = dz * 1.2 + 0.3 },
		minexptime = 0.1,
		maxexptime = 0.28,
		minsize = 1.5,
		maxsize = 3.5,
		texture = "default_mese_crystal_fragment.png^[colorize:#E0F2FE:160",
		glow = 14,
	})
end

--- Ghost / speed-reflection at a recent dash position.
local function emit_electric_afterimage(pos)
	core.add_particlespawner({
		amount = 8,
		time = 0.06,
		minpos = { x = pos.x - 0.5, y = pos.y - 0.1, z = pos.z - 0.5 },
		maxpos = { x = pos.x + 0.5, y = pos.y + 1.4, z = pos.z + 0.5 },
		minvel = { x = -0.2, y = 0.1, z = -0.2 },
		maxvel = { x = 0.2, y = 0.6, z = 0.2 },
		minexptime = 0.25,
		maxexptime = 0.55,
		minsize = 3.0,
		maxsize = 6.0,
		texture = "default_mese_crystal_fragment.png^[colorize:#FDE047:200",
		glow = 14,
	})
	core.add_particlespawner({
		amount = 4,
		time = 0.05,
		minpos = { x = pos.x - 0.3, y = pos.y + 0.2, z = pos.z - 0.3 },
		maxpos = { x = pos.x + 0.3, y = pos.y + 1.0, z = pos.z + 0.3 },
		minvel = { x = 0, y = 0.2, z = 0 },
		maxvel = { x = 0, y = 0.8, z = 0 },
		minexptime = 0.15,
		maxexptime = 0.35,
		minsize = 2.0,
		maxsize = 4.0,
		texture = "default_mese_crystal_fragment.png^[colorize:#E0F2FE:180",
		glow = 14,
	})
end

local function emit_skyrocket_burst(pos)
	core.add_particlespawner({
		amount = 30,
		time = 0.1,
		minpos = { x = pos.x - 0.7, y = pos.y - 0.4, z = pos.z - 0.7 },
		maxpos = { x = pos.x + 0.7, y = pos.y + 0.6, z = pos.z + 0.7 },
		minvel = { x = -2, y = -8, z = -2 },
		maxvel = { x = 2, y = -2, z = 2 },
		minexptime = 0.2,
		maxexptime = 0.55,
		minsize = 1.4,
		maxsize = 3.8,
		texture = "default_mese_crystal_fragment.png^[colorize:#E0F2FE:150",
		glow = 12,
	})
end

--- Dive: wind streaks rushing upward past the mount.
local function emit_dive_burst(pos)
	core.add_particlespawner({
		amount = 30,
		time = 0.1,
		minpos = { x = pos.x - 0.7, y = pos.y - 0.6, z = pos.z - 0.7 },
		maxpos = { x = pos.x + 0.7, y = pos.y + 0.4, z = pos.z + 0.7 },
		minvel = { x = -2, y = 2, z = -2 },
		maxvel = { x = 2, y = 10, z = 2 },
		minexptime = 0.2,
		maxexptime = 0.55,
		minsize = 1.4,
		maxsize = 3.8,
		texture = "default_mese_crystal_fragment.png^[colorize:#93C5FD:160",
		glow = 12,
	})
end

local ARC_DASH_GLOW = 14

local function set_arc_dash_glow(self, active)
	if not self or not self.object then
		return
	end
	if active then
		if not self._arc_glow_applied then
			if self._pre_mount_glow == nil then
				local props = self.object:get_properties()
				self._pre_mount_glow = (props and props.glow) or 0
			end
			self.object:set_properties({ glow = ARC_DASH_GLOW })
			self._arc_glow_applied = true
		end
	elseif self._arc_glow_applied then
		local restore = self._pre_mount_glow or 0
		-- Don't clobber active water biolum.
		if self._water_glow_applied and self._water_glow_level then
			self.object:set_properties({ glow = self._water_glow_level })
		else
			self.object:set_properties({ glow = restore })
		end
		self._arc_glow_applied = false
	end
end

local function node_is_walkable(pos)
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	return def and def.walkable == true
end

--- True if solid ground/wall is within `depth` nodes below `pos` (dive impact).
local function mount_solid_below(pos, depth)
	depth = depth or 2
	local x = math.floor(pos.x + 0.5)
	local z = math.floor(pos.z + 0.5)
	local y0 = math.floor(pos.y + 0.5)
	for dy = 0, depth do
		if node_is_walkable({ x = x, y = y0 - dy, z = z }) then
			return true
		end
	end
	return false
end

local function protect_rider_brief(player, seconds)
	if not player or not player.get_player_name then
		return
	end
	local props = player:get_properties()
	local saved = props and props.armor_groups
	player:set_armor_groups({ immortal = 1, fleshy = 100 })
	local name = player:get_player_name()
	core.after(seconds or 0.75, function()
		local p = core.get_player_by_name(name)
		if p then
			p:set_armor_groups(saved or { fleshy = 100 })
		end
	end)
end

--- Last free air along look_dir up to `dist` (legacy helper).
local function find_arc_dash_pos(from, look, dist)
	local last = { x = from.x, y = from.y, z = from.z }
	local steps = math.max(4, math.floor(dist * 2 + 0.5))
	for i = 1, steps do
		local t = (i / steps) * dist
		local p = {
			x = from.x + look.x * t,
			y = from.y + look.y * t,
			z = from.z + look.z * t,
		}
		local foot = {
			x = math.floor(p.x + 0.5),
			y = math.floor(p.y + 0.5),
			z = math.floor(p.z + 0.5),
		}
		local head = { x = foot.x, y = foot.y + 1, z = foot.z }
		local belly = { x = foot.x, y = foot.y + 2, z = foot.z }
		if node_is_walkable(foot) or node_is_walkable(head) or node_is_walkable(belly) then
			break
		end
		last = p
	end
	return last
end

local AIR_WIND_TEX = "default_mese_crystal_fragment.png^[colorize:#BFDBFE:100"
local AIR_WIND_STREAK_TEX = "default_mese_crystal_fragment.png^[colorize:#E0F2FE:140"
local AIR_HYPER_CORE_TEX = "default_mese_crystal_fragment.png^[colorize:#7DD3FC:180"

local function flat_flight_dir(dir)
	local len = math.sqrt(dir.x * dir.x + dir.z * dir.z)
	if len < 0.01 then
		return { x = 0, y = 0, z = -1 }
	end
	return { x = dir.x / len, y = 0, z = dir.z / len }
end

--- Hyper flight: wind streaks trailing behind the mount.
local function emit_air_hyper_trail(pos, dir)
	local d = flat_flight_dir(dir)
	core.add_particlespawner({
		amount = 22,
		time = 0.07,
		minpos = { x = pos.x - 0.55, y = pos.y - 0.15, z = pos.z - 0.55 },
		maxpos = { x = pos.x + 0.55, y = pos.y + 1.6, z = pos.z + 0.55 },
		minvel = { x = -d.x * 9 - 0.7, y = -0.5, z = -d.z * 9 - 0.7 },
		maxvel = { x = -d.x * 16 + 0.7, y = 0.9, z = -d.z * 16 + 0.7 },
		minacc = { x = -d.x * 2.5, y = 0, z = -d.z * 2.5 },
		maxacc = { x = -d.x * 5, y = 0.25, z = -d.z * 5 },
		minexptime = 0.12,
		maxexptime = 0.32,
		minsize = 1.0,
		maxsize = 2.6,
		texture = AIR_WIND_STREAK_TEX,
		glow = 10,
	})
	core.add_particlespawner({
		amount = 14,
		time = 0.07,
		minpos = { x = pos.x - 1.4, y = pos.y + 0.1, z = pos.z - 1.4 },
		maxpos = { x = pos.x + 1.4, y = pos.y + 2.0, z = pos.z + 1.4 },
		minvel = { x = -d.x * 11 - 2.2, y = -0.35, z = -d.z * 11 - 2.2 },
		maxvel = { x = -d.x * 18 + 2.2, y = 0.55, z = -d.z * 18 + 2.2 },
		minacc = { x = 0, y = 0, z = 0 },
		maxacc = { x = 0, y = 0.08, z = 0 },
		minexptime = 0.1,
		maxexptime = 0.25,
		minsize = 0.7,
		maxsize = 1.6,
		texture = AIR_WIND_TEX,
		glow = 8,
	})
end

--- Speed lines near the rider (visible in 1ª / 3ª persona durante hyper).
local function emit_air_rider_wind(rider_pos, dir)
	local d = flat_flight_dir(dir)
	local rx, ry, rz = rider_pos.x, rider_pos.y, rider_pos.z
	local ahead_x = rx + d.x * 2.8
	local ahead_z = rz + d.z * 2.8
	for _ = 1, 7 do
		local side = (math.random() - 0.5) * 2.8
		core.add_particle({
			pos = {
				x = ahead_x - d.z * side + (math.random() - 0.5) * 0.9,
				y = ry + 0.6 + math.random() * 1.4,
				z = ahead_z + d.x * side + (math.random() - 0.5) * 0.9,
			},
			velocity = {
				x = -d.x * (13 + math.random() * 7),
				y = (math.random() - 0.5) * 2.5,
				z = -d.z * (13 + math.random() * 7),
			},
			acceleration = { x = -d.x * 4, y = 0, z = -d.z * 4 },
			expirationtime = 0.16 + math.random() * 0.14,
			size = 0.55 + math.random() * 1.1,
			collisiondetection = false,
			texture = AIR_HYPER_CORE_TEX,
			glow = 12,
		})
	end
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
	ent._fire_propelling = false
	ent._fire_fx_t = 0

	if ent.rider then
		local rider = core.get_player_by_name(ent.rider)
		if rider then
			if profile.mode == "fly" then
				rider:set_physics_override({ speed = 0, jump = 0, gravity = 0 })
				ent.object:set_acceleration({ x = 0, y = 0, z = 0 })
				suspend_creatura_while_mounted(ent, true)
			else
				rider:set_physics_override({ speed = 0, jump = 0, gravity = 1 })
				ent.object:set_acceleration({ x = 0, y = GRAVITY, z = 0 })
				suspend_creatura_while_mounted(ent, false)
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

	-- Keep Creatura gravity in sync: its `_physics` writes accel from this every tick.
	if (self._mount_fly or (profile and profile.mode == "fly")) and self.set_gravity then
		self:set_gravity(0)
	end

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

	-- --- Electric: sustained sprint (run_boost anim when available) ---
	if mode == "ground" and profile.sprint and control.aux1 then
		speed = profile.sprint * dna_speed_mult(creature)
		self._mount_run_boost = true
	else
		self._mount_run_boost = false
	end

	-- Tick shared mobility cooldowns.
	self._arc_dash_cd = math.max(0, (self._arc_dash_cd or 0) - dtime)
	self._skyrocket_cd = math.max(0, (self._skyrocket_cd or 0) - dtime)
	self._dive_cd = math.max(0, (self._dive_cd or 0) - dtime)

	-- Bolt blink afterglow / residual surge.
	if self._arc_dash_glow_t and self._arc_dash_glow_t > 0
		and not ((self._arc_bolt_surge_t or 0) > 0) then
		self._arc_dash_glow_t = self._arc_dash_glow_t - dtime
		if self._arc_dash_glow_t <= 0 then
			self._arc_dash_glow_t = 0
			set_arc_dash_glow(self, false)
		end
	end

	-- Electric arc bolt: Jump edge + Sprint launches parabolic thunder.
	local arc_bolted = false
	if profile.arc_bolt and hashimon.launch_arc_bolt then
		local jump_edge = control.jump and not self._jump_was_down
		if jump_edge and control.aux1 and (self._arc_dash_cd or 0) <= 0 then
			local look = rider_obj:get_look_dir()
			local ok, err = hashimon.launch_arc_bolt(self, rider_obj, look)
			if ok then
				self._arc_dash_cd = profile.arc_bolt_cd or 2.5
				arc_bolted = true
				if not self._arc_dash_hint_sent then
					self._arc_dash_hint_sent = true
					core.chat_send_player(self.rider,
						"[Hashimon] Rayo — Salto+Sprint lanza trueno al cielo; blink al aterrizar (CD 2.5s).")
				end
			elseif err == "aim_down" then
				core.chat_send_player(self.rider,
					"[Hashimon] Mira al horizonte o al cielo para lanzar el rayo.")
			elseif err == "busy" then
				-- bolt still in flight
			end
		end
		self._jump_was_down = control.jump and true or false
	end

	-- --- Fuego: hold aux1 = ground/air propulsion (not flight) ---
	local fire_propel = false
	if profile.glide and control.aux1 then
		fire_propel = true
		self._fire_propelling = true
		local airborne = self._fire_jumped or math.abs(vel.y) > 0.15
		local propel_spd = airborne
			and (profile.propel_air or 26)
			or (profile.propel or 22)
		speed = propel_spd * dna_speed_mult(creature)
		self._fire_fx_t = (self._fire_fx_t or 0) + dtime
		if self._fire_fx_t >= 0.1 then
			self._fire_fx_t = 0
			emit_fire_trail(pos, dir)
		end
	elseif profile.glide then
		self._fire_propelling = false
	end

	-- --- Air: flight boost ---
	local boost = 1
	if mode == "fly" and control.aux1 then
		boost = profile.fly_boost or 3
		speed = cruise * boost
		self._mount_fly_boost = true
	else
		self._mount_fly_boost = false
	end

	-- Rocket feels committed: push forward even if W is idle while propelling.
	local move_fwd = forward
	if fire_propel and math.abs(move_fwd) < 0.05 then
		move_fwd = 1
	end
	local vx, vz = horizontal_velocity(dir, speed, move_fwd)
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
		-- Skyrocket / Dive: Space+Sprint up, Sneak+Sprint down. Both require Sprint.
		-- Jump+Sneak together = neither special (soft fly only).
		-- Dive held long enough arms a meteor strike; ground contact = TNT-like crater.
		local skyrocket_up = profile.skyrocket_up
		local dive_down = profile.dive_down or skyrocket_up
		local both_vert = control.jump and control.sneak
		local want_rocket = skyrocket_up
			and self._mount_fly_boost
			and control.jump
			and not control.sneak
			and not both_vert
		local want_dive = dive_down
			and self._mount_fly_boost
			and control.sneak
			and not control.jump
			and not both_vert

		local rocket_on = false
		local dive_on = false

		if want_rocket then
			if self._skyrocket_active then
				rocket_on = true
			elseif (self._skyrocket_cd or 0) <= 0 then
				self._skyrocket_active = true
				self._skyrocket_t = 0
				self._skyrocket_start_y = pos.y
				rocket_on = true
				emit_skyrocket_burst(pos)
			end
		end
		if want_dive then
			if self._dive_active then
				dive_on = true
			elseif (self._dive_cd or 0) <= 0 then
				self._dive_active = true
				self._dive_t = 0
				self._dive_start_y = pos.y
				self._meteor_armed = false
				self._meteor_peak = 0
				dive_on = true
				emit_dive_burst(pos)
			end
		end

		if rocket_on then
			self._skyrocket_t = (self._skyrocket_t or 0) + dtime
			local gain = pos.y - (self._skyrocket_start_y or pos.y)
			local max_t = profile.skyrocket_max_t or 3.0
			if self._skyrocket_t >= max_t or gain >= 250 then
				self._skyrocket_active = false
				self._skyrocket_cd = profile.skyrocket_cd or 8.0
				rocket_on = false
			end
		elseif self._skyrocket_active then
			self._skyrocket_active = false
			self._skyrocket_cd = profile.skyrocket_cd or 8.0
		end

		if dive_on then
			self._dive_t = (self._dive_t or 0) + dtime
			local drop = (self._dive_start_y or pos.y) - pos.y
			local max_t = profile.dive_max_t or 3.0
			local arm_t = hashimon.METEOR_ARM_T or 0.35
			if self._dive_t >= arm_t then
				self._meteor_armed = true
			end
			if self._dive_t >= max_t or drop >= 250 then
				self._dive_active = false
				self._dive_cd = profile.dive_cd or 8.0
				dive_on = false
			end
		elseif self._dive_active then
			self._dive_active = false
			self._dive_cd = profile.dive_cd or 8.0
		end

		local function apply_special_horiz()
			local h_spd = cruise * math.max(boost * 0.85, 1)
			if math.abs(forward) < 0.05 then
				return horizontal_velocity(dir, h_spd, 1)
			end
			return horizontal_velocity(dir, h_spd, forward)
		end

		if rocket_on then
			vy = skyrocket_up
			vx, vz = apply_special_horiz()
			self._air_fx_t = (self._air_fx_t or 0) + dtime
			if self._air_fx_t >= 0.04 then
				self._air_fx_t = 0
				emit_skyrocket_burst(pos)
				emit_air_hyper_trail(pos, dir)
				local rider_pos = rider_obj:get_pos()
				if rider_pos then
					emit_air_rider_wind(rider_pos, dir)
				end
			end
		elseif dive_on then
			vy = -(dive_down or 80)
			vx, vz = apply_special_horiz()
			local spd = math.sqrt(vx * vx + vy * vy + vz * vz)
			self._meteor_peak = math.max(self._meteor_peak or 0, spd, -vy)
			self._air_fx_t = (self._air_fx_t or 0) + dtime
			if self._air_fx_t >= 0.04 then
				self._air_fx_t = 0
				emit_dive_burst(pos)
				emit_air_hyper_trail(pos, dir)
				local rider_pos = rider_obj:get_pos()
				if rider_pos then
					emit_air_rider_wind(rider_pos, dir)
				end
			end
		elseif control.jump then
			vy = FLY_UP * boost
		elseif control.sneak then
			vy = -FLY_DOWN * boost
		elseif math.abs(vx) + math.abs(vz) < 0.01 then
			vy = FLY_HOVER
		else
			vy = math.max(vy * 0.9, FLY_HOVER)
		end

		-- Keep peak while armed and still falling after dive budget ends.
		if self._meteor_armed and not dive_on and vel.y < -12 then
			local spd = math.sqrt(vx * vx + vy * vy + vz * vz)
			self._meteor_peak = math.max(self._meteor_peak or 0, spd, -vel.y)
		elseif self._meteor_armed and not dive_on and vel.y > -8
			and not mount_solid_below(pos, 2) then
			-- Soft cancel: left dive and no longer plummeting.
			self._meteor_armed = false
			self._meteor_peak = 0
		end

		-- Direct ground impact → meteor crater (radius scales with peak dive speed).
		if self._meteor_armed and hashimon.meteor_strike then
			local look_depth = 2
			if dive_on or (vel.y and vel.y < -20) then
				look_depth = math.min(6, 2 + math.floor((self._meteor_peak or 40) * 0.04))
			end
			if mount_solid_below(pos, look_depth) then
				local impact_spd = math.max(self._meteor_peak or 0, -(vy < 0 and vy or vel.y or 0))
				protect_rider_brief(rider_obj, 0.85)
				local radius = hashimon.meteor_strike(pos, impact_spd, self.rider)
				self._meteor_armed = false
				self._meteor_peak = 0
				self._dive_active = false
				self._dive_cd = math.max(self._dive_cd or 0, profile.dive_cd or 8.0)
				dive_on = false
				vy = math.min(vy, 8)
				vx, vz = vx * 0.25, vz * 0.25
				if radius and radius > 0 then
					core.chat_send_player(self.rider, string.format(
						"[Hashimon] Meteorito — impacto %.0f n/s, cráter r=%d.",
						impact_spd, radius))
					emit_dive_burst(pos)
				end
			end
		end

		if self._mount_fly_boost and not rocket_on and not dive_on then
			self._air_fx_t = (self._air_fx_t or 0) + dtime
			if self._air_fx_t >= 0.07 then
				self._air_fx_t = 0
				emit_air_hyper_trail(pos, dir)
				local rider_pos = rider_obj:get_pos()
				if rider_pos then
					emit_air_rider_wind(rider_pos, dir)
				end
			end
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
		-- Gravity always on for Fuego — propulsion is thrust, not flight.
		if not in_liquid then
			self.object:set_acceleration({ x = 0, y = GRAVITY, z = 0 })
		end

		local jump_v = profile.jump or JUMP_DEFAULT
		local on_ground = math.abs(vel.y) < 0.08

		if profile.glide then
			-- Fire: super jump, then glide / propelled leap until landing.
			if control.jump and on_ground and not self._fire_jumped then
				vy = jump_v
				self._fire_jumped = true
				self._mount_glide = false
			elseif self._fire_jumped then
				if vel.y <= 0.4 then
					self._mount_glide = true
				end
				if fire_propel then
					-- Mid-air aux1: hard horizontal already applied; soft fall only.
					local fall_cap = -GLIDE_GRAVITY * 8
					if vy < fall_cap then
						vy = fall_cap
					end
				elseif self._mount_glide then
					-- Snappier non-boost glide: less float, stronger forward carry.
					local fall_cap = -GLIDE_GRAVITY * 16
					if vy < fall_cap then
						vy = fall_cap
					end
					vy = vy * 0.96
					if math.abs(forward) < 0.05 then
						vx = dir.x * cruise * 0.7 * GLIDE_FORWARD
						vz = dir.z * cruise * 0.7 * GLIDE_FORWARD
					end
				end
				if on_ground and vel.y <= 0.05 then
					self._fire_jumped = false
					self._mount_glide = false
				end
			elseif control.jump and on_ground then
				vy = jump_v
			end

			-- Ground propulsion soft-fall does nothing; airborne without jump
			-- flag still gets a mild fall clamp while thrusting.
			if fire_propel and not on_ground and not self._fire_jumped then
				local fall_cap = -GLIDE_GRAVITY * 8
				if vy < fall_cap then
					vy = fall_cap
				end
			end
		else
			-- Arc bolt consumes jump+Sprint; plain jump without Sprint.
			if control.jump and on_ground and not (profile.arc_bolt and control.aux1)
				and not arc_bolted then
				vy = jump_v
			end
		end
	end

	-- Short residual after bolt blink lands.
	if (self._arc_bolt_surge_t or 0) > 0 then
		self._arc_bolt_surge_t = self._arc_bolt_surge_t - dtime
		local look = self._arc_bolt_look or dir
		vx = look.x * 16
		vz = look.z * 16
		vy = math.max(vy, look.y * 8, 3)
		set_arc_dash_glow(self, true)
		if self._arc_bolt_surge_t <= 0 then
			self._arc_bolt_surge_t = 0
			self._arc_dash_glow_t = 0.2
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

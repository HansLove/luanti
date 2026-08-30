-- Admin possession: attach player to villain entity and drive movement from input.
-- Camera/seat/speed come from monster profiles; flyers get sprint boost.

hashimon_villain = hashimon_villain or {}

hashimon_villain.possessions = hashimon_villain.possessions or {} -- [player_name] = entity ObjectRef
hashimon_villain.POSSESS_RANGE = 8

local POSSESS_SPEED = 5
local POSSESS_REVERSE = 0.5
local JUMP_VELOCITY = 6.5
local FLY_UP = 4
local FLY_DOWN = 3
local FLY_HOVER = 0.15

local function profile_for(ent)
	return ent.monster_profile or hashimon_villain.get_profile(ent.body_id)
end

local function seat_from_profile(profile)
	return (profile and profile.seat) or { x = 0, y = 1.0, z = 0 }
end

local function eyes_from_profile(profile)
	return {
		first = (profile and profile.eye_first) or { x = 0, y = 1.5, z = 0 },
		third = (profile and profile.eye_third) or { x = 0, y = 2.5, z = -4 },
	}
end

local function hide_player(player)
	local props = player:get_properties()
	hashimon_villain._saved_player_props = hashimon_villain._saved_player_props or {}
	hashimon_villain._saved_player_props[player:get_player_name()] = {
		pointable = props.pointable,
		visual_size = props.visual_size,
	}
	player:set_properties({
		pointable = false,
		visual_size = { x = 0.001, y = 0.001 },
	})
	player:set_nametag_attributes({ text = "" })
end

local function restore_player(player)
	local name = player:get_player_name()
	local saved = hashimon_villain._saved_player_props and hashimon_villain._saved_player_props[name]
	if saved then
		player:set_properties({
			pointable = saved.pointable,
			visual_size = saved.visual_size,
		})
		hashimon_villain._saved_player_props[name] = nil
	else
		player:set_properties({
			pointable = true,
			visual_size = { x = 1, y = 1 },
		})
	end
end

function hashimon_villain.possess(player, entity_obj)
	if not player or not entity_obj then
		return false, "invalid"
	end
	local name = player:get_player_name()
	local ent = entity_obj:get_luaentity()
	if not ent or not ent.body_id or ent.possessor then
		return false, "busy"
	end

	if hashimon_villain.possessions[name] then
		hashimon_villain.release(player)
	end

	local body_id = ent.body_id
	local profile = profile_for(ent)
	ent.monster_profile = profile
	local seat = seat_from_profile(profile)
	local eyes = eyes_from_profile(profile)
	local caps = (ent.body_def and ent.body_def.capabilities) or {}
	local is_flyer = hashimon_villain.is_flyer_profile(profile) or caps.fly

	player:set_attach(entity_obj, "", seat, { x = 0, y = 0, z = 0 })
	if is_flyer then
		player:set_physics_override({ speed = 0, jump = 0, gravity = 0 })
	else
		player:set_physics_override({ speed = 0, jump = 0 })
	end
	player:set_eye_offset(eyes.first, eyes.third)
	hide_player(player)

	ent.possessor = name
	ent.controller_mode = hashimon_villain.CONTROLLER_HUMAN
	ent.possess_speed = profile.fly_speed or ent.possess_speed
	hashimon_villain.possessions[name] = entity_obj

	core.chat_send_player(name,
		"[HV] Posesión activa — " .. hashimon_villain.possess_controls_hint(body_id))
	return true
end

function hashimon_villain.release(player)
	if not player or not player.get_player_name then
		return false
	end
	local name = player:get_player_name()
	local entity_obj = hashimon_villain.possessions[name]

	player:set_detach()
	player:set_physics_override({ speed = 1, jump = 1, gravity = 1 })
	player:set_eye_offset({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 })
	restore_player(player)

	if entity_obj then
		local ent = entity_obj:get_luaentity()
		if ent and ent.possessor == name then
			ent.possessor = nil
			ent.controller_mode = hashimon_villain.CONTROLLER_AI
		end
	end
	hashimon_villain.possessions[name] = nil

	if entity_obj then
		core.chat_send_player(name, "[HV] Posesión liberada — el villano vuelve a modo IA.")
	end
	return true
end

function hashimon_villain.nearest_villain(pos, max_dist)
	if not pos then
		return nil
	end
	max_dist = max_dist or hashimon_villain.POSSESS_RANGE
	local nearest
	local nearest_dist = max_dist * max_dist
	for _, obj in ipairs(core.get_objects_inside_radius(pos, max_dist)) do
		local ent = obj:get_luaentity()
		if ent and ent.name and ent.name:match("^hashimon_villain:") and not ent.possessor then
			local epos = obj:get_pos()
			if epos then
				local dx, dy, dz = epos.x - pos.x, epos.y - pos.y, epos.z - pos.z
				local dist = dx * dx + dy * dy + dz * dz
				if dist < nearest_dist then
					nearest_dist = dist
					nearest = obj
				end
			end
		end
	end
	return nearest
end

function hashimon_villain.step_possessed(self, dtime)
	local rider_obj = core.get_player_by_name(self.possessor)
	local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }

	if not rider_obj or not rider_obj:is_player() then
		self.possessor = nil
		self.controller_mode = hashimon_villain.CONTROLLER_AI
		self.object:set_velocity({ x = 0, y = vel.y, z = 0 })
		return
	end

	local profile = profile_for(self)
	local caps = (self.body_def and self.body_def.capabilities) or {}
	local is_flyer = hashimon_villain.is_flyer_profile(profile) or caps.fly
	local control = rider_obj:get_player_control()
	local yaw = rider_obj:get_look_horizontal()
	self.object:set_yaw(yaw)

	local dir = core.yaw_to_dir(yaw)
	local speed = self.possess_speed
		or (profile and profile.fly_speed)
		or (is_flyer and 10 or POSSESS_SPEED)

	local boost = 1
	if is_flyer and control.aux1 then
		boost = (profile and profile.fly_boost) or 2.0
		speed = speed * boost
	end

	local forward = control.movement_y or 0
	if forward == 0 then
		if control.up then forward = 1
		elseif control.down then forward = -1 end
	end

	local vx, vz = 0, 0
	if forward > 0.05 then
		vx, vz = dir.x * speed * forward, dir.z * speed * forward
	elseif forward < -0.05 then
		local s = speed * POSSESS_REVERSE
		vx, vz = dir.x * s * forward, dir.z * s * forward
	end

	local vy = vel.y
	if is_flyer then
		if control.jump then
			vy = FLY_UP * boost
		elseif control.sneak then
			vy = -FLY_DOWN * boost
		elseif math.abs(vx) + math.abs(vz) < 0.01 then
			vy = FLY_HOVER
		else
			vy = math.max(vy * 0.9, FLY_HOVER)
		end
	else
		if control.jump and math.abs(vel.y) < 0.05 then
			vy = JUMP_VELOCITY
		end
	end

	self.object:set_velocity({ x = vx, y = vy, z = vz })

	if hashimon_villain.step_possessed_attack then
		hashimon_villain.step_possessed_attack(self, rider_obj, control, dtime)
	end
end

core.register_on_leaveplayer(function(player)
	hashimon_villain.release(player)
end)

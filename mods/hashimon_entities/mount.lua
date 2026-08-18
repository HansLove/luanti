-- Riding: once a Hashimon has grown enough (stage-gated), its owner can
-- right-click to mount and steer it. Same attach/control-redirect pattern
-- every Luanti horse/boat mod uses (player:set_attach + get_player_control +
-- set_physics_override), applied to our voxel body's root entity.
--
-- Speed comes from the DNA-compiled build/size traits, not combat stats:
-- api/'s Phase 1 payload (see api/src/domain/hashimons.ts present()) only
-- exposes identity + PoW progression, no hp/atk/def/spd/luck — those aren't
-- computed server-side yet. Once they are, this is the one place to switch
-- the speed formula over to them.

hashimon = hashimon or {}

hashimon.MOUNT_STAGE_THRESHOLD = 10
hashimon.mounts = hashimon.mounts or {} -- [player_name] = mount ObjectRef

local MOUNT_BASE_SPEED = 6
local MOUNT_MIN_SPEED = 3
local MOUNT_MAX_SPEED = 10
local MOUNT_REVERSE_FACTOR = 0.5
local JUMP_VELOCITY = 6.5

local BUILD_SPEED = {
	delicate = 1.25, lean = 1.15, balanced = 1.0, stocky = 0.9,
	muscular = 0.85, bulbous = 0.7, angular = 1.05, round = 0.95,
}
local SIZE_SPEED = {
	diminutive = 0.8, small = 0.9, medium = 1.0, large = 1.1, huge = 1.2, massive = 1.3,
}

function hashimon.is_rideable(creature)
	return hashimon.creature_stage(creature) >= hashimon.MOUNT_STAGE_THRESHOLD
end

--- DNA-derived mount speed (nodes/sec). See file header for why this isn't
--- combat-stat-driven yet.
function hashimon.mount_speed_for(creature)
	if not creature or not creature.dna then
		return MOUNT_BASE_SPEED
	end
	local element_type = hashimon.type_for_creature(creature)
	local look = hashimon.compile_look(creature.dna, element_type)
	if not look then
		return MOUNT_BASE_SPEED
	end
	local mult = (BUILD_SPEED[look.build] or 1.0) * (SIZE_SPEED[look.size] or 1.0)
	local speed = MOUNT_BASE_SPEED * mult
	if speed < MOUNT_MIN_SPEED then speed = MOUNT_MIN_SPEED end
	if speed > MOUNT_MAX_SPEED then speed = MOUNT_MAX_SPEED end
	return speed
end

--- Try to mount `player` on `mount_obj` (a hashimon_entities:voxel_root).
--- Returns true on success. Caller (on_rightclick) already checked
--- rideable/ownership/no-existing-rider.
function hashimon.mount(player, mount_obj)
	local name = player:get_player_name()
	if hashimon.mounts[name] then
		hashimon.dismount(player)
	end

	local ent = mount_obj:get_luaentity()
	if not ent or ent.rider then
		return false
	end

	local seat_y = 4 * (ent.size_mult or 1.0) -- ×10 attach scale = 0.4 node-space, size-aware
	player:set_attach(mount_obj, "", { x = 0, y = seat_y, z = 0 }, { x = 0, y = 0, z = 0 })
	player:set_physics_override({ speed = 0, jump = 0 })
	player:set_eye_offset({ x = 0, y = 2, z = 0 }, { x = 0, y = 3, z = -4 })

	ent.rider = name
	ent.mount_speed = hashimon.mount_speed_for(ent.creature)
	hashimon.mounts[name] = mount_obj

	core.chat_send_player(name,
		"[Hashimon] Montado — WASD para dirigir, espacio para saltar, click derecho de nuevo para bajar.")
	return true
end

--- Dismount whatever `player` is currently riding, if anything. Safe to call
--- even if they aren't mounted (used defensively on disconnect).
function hashimon.dismount(player)
	if not player or not player.get_player_name then
		return false
	end
	local name = player:get_player_name()
	local mount_obj = hashimon.mounts[name]

	player:set_detach()
	player:set_physics_override({ speed = 1, jump = 1 })
	player:set_eye_offset({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 })

	if mount_obj then
		local ent = mount_obj:get_luaentity()
		if ent and ent.rider == name then
			ent.rider = nil
			ent.mount_speed = nil
		end
	end
	hashimon.mounts[name] = nil

	if mount_obj then
		core.chat_send_player(name, "[Hashimon] Desmontado.")
	end
	return true
end

--- Called from voxel_root's on_step whenever self.rider is set: reads the
--- rider's input and steers the mount accordingly. Forward/back only for
--- v1 (matches simple horse-mod conventions) — no strafing.
function hashimon.step_mounted(self)
	local rider_obj = core.get_player_by_name(self.rider)
	local vel = self.object:get_velocity()

	if not rider_obj or not rider_obj:is_player() then
		-- Rider disconnected/crashed without a clean dismount — release safely
		-- rather than leaving the mount stuck steering toward nothing.
		self.rider = nil
		self.mount_speed = nil
		self.object:set_velocity({ x = 0, y = vel.y, z = 0 })
		return
	end

	local yaw = rider_obj:get_look_horizontal()
	self.object:set_yaw(yaw)

	local control = rider_obj:get_player_control()
	local speed = self.mount_speed or hashimon.mount_speed_for(self.creature)
	local dir = core.yaw_to_dir(yaw)

	local forward = control.movement_y or 0
	if forward == 0 then
		if control.up then forward = 1
		elseif control.down then forward = -1 end
	end

	if forward > 0.05 then
		self.object:set_velocity({ x = dir.x * speed * forward, y = vel.y, z = dir.z * speed * forward })
	elseif forward < -0.05 then
		local s = speed * MOUNT_REVERSE_FACTOR
		self.object:set_velocity({ x = dir.x * s * forward, y = vel.y, z = dir.z * s * forward })
	else
		self.object:set_velocity({ x = 0, y = vel.y, z = 0 })
	end

	if control.jump and math.abs(vel.y) < 0.05 then
		self.object:add_velocity({ x = 0, y = JUMP_VELOCITY, z = 0 })
	end
end

-- Safety net: never leave a player stuck attached/physics-frozen after they
-- disconnect while mounted.
core.register_on_leaveplayer(function(player)
	hashimon.dismount(player)
end)

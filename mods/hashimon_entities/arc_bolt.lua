-- Electric mount special: parabolic thunder bolt → blink mount to last free air.

hashimon = hashimon or {}

local BOLT_SPEED = 32
local BOLT_GRAVITY = -20
local BOLT_TIMEOUT = 1.4
local BOLT_TEX = "default_mese_crystal_fragment.png^[colorize:#FDE047:200"
local BOLT_TEX2 = "default_mese_crystal_fragment.png^[colorize:#E0F2FE:180"

hashimon._arc_bolts = hashimon._arc_bolts or {} -- [player_name] = ObjectRef

local function normalize(dir)
	local len = math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
	if len < 0.001 then
		return { x = 0, y = 1, z = 0 }
	end
	return { x = dir.x / len, y = dir.y / len, z = dir.z / len }
end

local function node_walkable(pos)
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	return def and def.walkable == true
end

--- Feet + head + belly free of walkable nodes.
local function is_free_mount_air(pos)
	local foot = {
		x = math.floor(pos.x + 0.5),
		y = math.floor(pos.y + 0.5),
		z = math.floor(pos.z + 0.5),
	}
	local head = { x = foot.x, y = foot.y + 1, z = foot.z }
	local belly = { x = foot.x, y = foot.y + 2, z = foot.z }
	return not node_walkable(foot) and not node_walkable(head) and not node_walkable(belly)
end

local function emit_bolt_trail(pos)
	core.add_particlespawner({
		amount = 10,
		time = 0.06,
		minpos = { x = pos.x - 0.2, y = pos.y - 0.2, z = pos.z - 0.2 },
		maxpos = { x = pos.x + 0.2, y = pos.y + 0.2, z = pos.z + 0.2 },
		minvel = { x = -0.5, y = -0.5, z = -0.5 },
		maxvel = { x = 0.5, y = 0.8, z = 0.5 },
		minexptime = 0.12,
		maxexptime = 0.3,
		minsize = 1.2,
		maxsize = 2.8,
		texture = BOLT_TEX,
		glow = 14,
	})
end

local function emit_blink_fx(from, to)
	core.add_particlespawner({
		amount = 24,
		time = 0.12,
		minpos = {
			x = math.min(from.x, to.x) - 0.3,
			y = math.min(from.y, to.y) - 0.2,
			z = math.min(from.z, to.z) - 0.3,
		},
		maxpos = {
			x = math.max(from.x, to.x) + 0.3,
			y = math.max(from.y, to.y) + 1.0,
			z = math.max(from.z, to.z) + 0.3,
		},
		minvel = { x = -0.4, y = 0, z = -0.4 },
		maxvel = { x = 0.4, y = 1.2, z = 0.4 },
		minexptime = 0.15,
		maxexptime = 0.4,
		minsize = 1.5,
		maxsize = 3.5,
		texture = BOLT_TEX,
		glow = 14,
	})
	core.add_particlespawner({
		amount = 10,
		time = 0.08,
		minpos = { x = to.x - 0.4, y = to.y, z = to.z - 0.4 },
		maxpos = { x = to.x + 0.4, y = to.y + 1.2, z = to.z + 0.4 },
		minvel = { x = -0.3, y = 0.5, z = -0.3 },
		maxvel = { x = 0.3, y = 1.5, z = 0.3 },
		minexptime = 0.2,
		maxexptime = 0.45,
		minsize = 2,
		maxsize = 4,
		texture = BOLT_TEX2,
		glow = 14,
	})
end

local function clear_owner_bolt(name)
	local obj = hashimon._arc_bolts[name]
	if obj and obj:get_luaentity() then
		obj:remove()
	end
	hashimon._arc_bolts[name] = nil
end

--- Blink mount to free air at `pos`. Called when the bolt lands.
function hashimon.arc_bolt_land(owner_name, pos)
	if not owner_name or not pos then
		return false
	end
	hashimon._arc_bolts[owner_name] = nil

	local mount_obj = hashimon.mounts and hashimon.mounts[owner_name]
	if not mount_obj or not mount_obj:get_luaentity() then
		return false
	end
	local ent = mount_obj:get_luaentity()
	local from = mount_obj:get_pos()
	if not from then
		return false
	end

	local dest = pos
	if not is_free_mount_air(dest) then
		-- Search upward a bit for free air (never blink into stone).
		local found = false
		for dy = 0, 4 do
			local p = { x = dest.x, y = dest.y + dy, z = dest.z }
			if is_free_mount_air(p) then
				dest = p
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end

	emit_blink_fx(from, dest)
	mount_obj:set_pos(dest)

	-- Brief residual + glow handled by mount step.
	ent._arc_bolt_surge_t = 0.35
	ent._arc_dash_glow_t = 0
	if ent.object then
		local props = ent.object:get_properties()
		if ent._pre_mount_glow == nil then
			ent._pre_mount_glow = (props and props.glow) or 0
		end
		ent.object:set_properties({ glow = 14 })
		ent._arc_glow_applied = true
	end
	local look = ent._arc_bolt_look or { x = 0, y = 0, z = 1 }
	mount_obj:set_velocity({
		x = look.x * 18,
		y = math.max(4, look.y * 10),
		z = look.z * 18,
	})
	ent._arc_bolt_obj = nil
	return true
end

function hashimon.clear_arc_bolt(owner_name)
	clear_owner_bolt(owner_name)
end

local function finish_bolt(self, land_pos)
	local owner = self.owner
	local air = self._last_air or land_pos
	if self.object then
		self.object:remove()
	end
	if owner then
		hashimon.arc_bolt_land(owner, air)
	end
end

core.register_entity("hashimon_entities:arc_bolt", {
	initial_properties = {
		visual = "sprite",
		textures = { BOLT_TEX },
		visual_size = { x = 0.55, y = 0.55 },
		physical = false,
		collide_with_objects = false,
		collisionbox = { -0.15, -0.15, -0.15, 0.15, 0.15, 0.15 },
		static_save = false,
		glow = 14,
		pointable = false,
	},

	owner = nil,
	_vel = nil,
	_age = 0,
	_last_air = nil,
	_fx_t = 0,

	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1, fleshy = 0 })
	end,

	on_step = function(self, dtime)
		self._age = (self._age or 0) + dtime
		local pos = self.object:get_pos()
		if not pos then
			return
		end

		if self._age >= BOLT_TIMEOUT then
			finish_bolt(self, pos)
			return
		end

		local vel = self._vel or { x = 0, y = 10, z = 0 }
		vel.y = vel.y + BOLT_GRAVITY * dtime
		self._vel = vel

		local next_pos = {
			x = pos.x + vel.x * dtime,
			y = pos.y + vel.y * dtime,
			z = pos.z + vel.z * dtime,
		}

		-- Track free air along the path for a safe blink destination.
		if is_free_mount_air(pos) then
			self._last_air = { x = pos.x, y = pos.y, z = pos.z }
		end

		local hit = false
		local ray = core.raycast(pos, next_pos, false, false)
		for pointed in ray do
			if pointed.type == "node" then
				hit = true
				break
			end
		end
		-- Also treat entering a walkable node as landing.
		if not hit then
			local check = {
				x = math.floor(next_pos.x + 0.5),
				y = math.floor(next_pos.y + 0.5),
				z = math.floor(next_pos.z + 0.5),
			}
			if node_walkable(check) then
				hit = true
			end
		end

		if hit then
			finish_bolt(self, self._last_air or pos)
			return
		end

		self.object:set_pos(next_pos)
		self._fx_t = (self._fx_t or 0) + dtime
		if self._fx_t >= 0.04 then
			self._fx_t = 0
			emit_bolt_trail(next_pos)
		end
	end,
})

--- Launch parabolic bolt from mount. Returns true, or false, err.
--- err: "aim_down" | "busy" | "spawn_failed"
function hashimon.launch_arc_bolt(mount_ent, rider, look)
	if not mount_ent or not mount_ent.object or not rider then
		return false, "spawn_failed"
	end
	local name = rider:get_player_name()
	look = look or rider:get_look_dir()
	if not look then
		return false, "spawn_failed"
	end
	if look.y < -0.2 then
		return false, "aim_down"
	end

	-- Force a skyward parabola: never launch into the ground.
	local aim = normalize({
		x = look.x,
		y = math.max(look.y, 0.15),
		z = look.z,
	})

	if hashimon._arc_bolts[name] then
		return false, "busy"
	end

	local mpos = mount_ent.object:get_pos()
	if not mpos then
		return false, "spawn_failed"
	end
	local spawn = {
		x = mpos.x + aim.x * 1.2,
		y = mpos.y + 1.2 + aim.y * 0.5,
		z = mpos.z + aim.z * 1.2,
	}

	local obj = core.add_entity(spawn, "hashimon_entities:arc_bolt")
	if not obj then
		return false, "spawn_failed"
	end

	local ent = obj:get_luaentity()
	if not ent then
		obj:remove()
		return false, "spawn_failed"
	end

	local speed = BOLT_SPEED
	ent.owner = name
	ent._vel = {
		x = aim.x * speed,
		y = math.max(8, aim.y * speed),
		z = aim.z * speed,
	}
	ent._last_air = { x = spawn.x, y = spawn.y, z = spawn.z }
	ent._age = 0

	hashimon._arc_bolts[name] = obj
	mount_ent._arc_bolt_obj = obj
	mount_ent._arc_bolt_look = { x = aim.x, y = aim.y, z = aim.z }

	emit_bolt_trail(spawn)
	return true
end

core.log("action", "[hashimon_entities] arc_bolt loaded (electric parabolic blink)")

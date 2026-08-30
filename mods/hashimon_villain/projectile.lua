-- Breath projectile — damage + ignite flammable nodes (no stone destruction).

hashimon_villain = hashimon_villain or {}

local BREATH_SPEED = 18
local BREATH_TIMEOUT = 3
local BREATH_DAMAGE = 7
local BREATH_COOLDOWN = 1.2

hashimon_villain._breath_cd = hashimon_villain._breath_cd or {}

local function normalize_dir(dir)
	local len = math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
	if len < 0.001 then
		return { x = 0, y = 0, z = 1 }
	end
	return { x = dir.x / len, y = dir.y / len, z = dir.z / len }
end

local function breath_texture(profile)
	local tint = (profile and profile.breath_tint) or "#F97316"
	return "fire_basic_flame.png^[colorize:" .. tint .. ":200"
end

local function should_hit(shooter_ref, owner_name, obj)
	if not obj or obj == shooter_ref then
		return false
	end
	local owner = owner_name and core.get_player_by_name(owner_name)
	if owner and obj == owner then
		return false
	end
	local ent = obj:get_luaentity()
	if ent and ent.name == "hashimon_villain:breath_orb" then
		return false
	end
	return true
end

local function ray_impact(self, from_pos, to_pos)
	local ray = core.raycast(from_pos, to_pos, true, false)
	for pointed in ray do
		if pointed.type == "node" then
			return pointed.under, "node"
		end
		if pointed.type == "object" and pointed.ref and should_hit(self.shooter_ref, self.owner, pointed.ref) then
			return pointed.under or pointed.ref:get_pos(), "object", pointed.ref
		end
	end
	return nil
end

local function apply_damage(obj, damage, shooter)
	obj:punch(shooter or obj, 1.0, {
		full_punch_interval = 1.0,
		damage_groups = { fleshy = damage },
	}, nil)
end

local function impact_particles(pos, texture)
	core.add_particlespawner({
		amount = 12,
		time = 0.1,
		minpos = { x = pos.x - 0.3, y = pos.y - 0.3, z = pos.z - 0.3 },
		maxpos = { x = pos.x + 0.3, y = pos.y + 0.3, z = pos.z + 0.3 },
		minvel = { x = -1, y = 0, z = -1 },
		maxvel = { x = 1, y = 2, z = 1 },
		minexptime = 0.3,
		maxexptime = 0.6,
		minsize = 1,
		maxsize = 2,
		collisiondetection = false,
		texture = texture or "fire_basic_flame.png",
	})
end

--- Place fire:basic_flame next to a flammable node (wood, leaves, trees).
local function try_ignite(pos)
	if not pos or not core.registered_nodes["fire:basic_flame"] then
		return false
	end
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	if not def or not def.groups or not def.groups.flammable then
		return false
	end
	local offsets = {
		{ x = 0, y = 1, z = 0 },
		{ x = 1, y = 0, z = 0 },
		{ x = -1, y = 0, z = 0 },
		{ x = 0, y = 0, z = 1 },
		{ x = 0, y = 0, z = -1 },
		{ x = 0, y = -1, z = 0 },
	}
	for _, off in ipairs(offsets) do
		local p = { x = pos.x + off.x, y = pos.y + off.y, z = pos.z + off.z }
		if core.get_node(p).name == "air" then
			core.set_node(p, { name = "fire:basic_flame" })
			return true
		end
	end
	return false
end

core.register_entity("hashimon_villain:breath_orb", {
	initial_properties = {
		visual = "sprite",
		textures = { "fire_basic_flame.png" },
		visual_size = { x = 0.4, y = 0.4 },
		physical = false,
		collide_with_objects = false,
		collisionbox = { -0.12, -0.12, -0.12, 0.12, 0.12, 0.12 },
		static_save = false,
		glow = 10,
	},

	owner = nil,
	shooter_ref = nil,
	_dir = nil,
	_speed = BREATH_SPEED,
	_damage = BREATH_DAMAGE,
	_texture = "fire_basic_flame.png",
	_age = 0,

	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1, fleshy = 0 })
	end,

	on_step = function(self, dtime)
		self._age = (self._age or 0) + dtime
		if self._age >= BREATH_TIMEOUT then
			self.object:remove()
			return
		end

		local pos = self.object:get_pos()
		if not pos then
			return
		end

		local dir = self._dir or { x = 0, y = 0, z = 1 }
		local speed = self._speed or BREATH_SPEED
		local next_pos = {
			x = pos.x + dir.x * speed * dtime,
			y = pos.y + dir.y * speed * dtime,
			z = pos.z + dir.z * speed * dtime,
		}

		local hit_pos, hit_kind, hit_ref = ray_impact(self, pos, next_pos)
		if hit_pos then
			if hit_kind == "object" and hit_ref then
				apply_damage(hit_ref, self._damage or BREATH_DAMAGE, self.shooter_ref)
			elseif hit_kind == "node" then
				try_ignite(hit_pos)
			end
			impact_particles(hit_pos, self._texture)
			core.sound_play("fire_extinguish_flame", { pos = hit_pos, max_hear_distance = 14 }, true)
			self.object:remove()
			return
		end

		self.object:set_pos(next_pos)
	end,
})

function hashimon_villain.can_breath(cooldown_key)
	local t = hashimon_villain._breath_cd[cooldown_key]
	return not t or t <= core.get_us_time()
end

function hashimon_villain.mark_breath(cooldown_key)
	hashimon_villain._breath_cd[cooldown_key] = core.get_us_time() + BREATH_COOLDOWN * 1e6
end

--- Launch breath from head offset (profile.breath_spawn), not torso center.
function hashimon_villain.launch_breath(entity_obj, direction, owner_name, profile, cooldown_key)
	if not entity_obj or not entity_obj:get_pos() then
		return false
	end
	cooldown_key = cooldown_key or owner_name or "ai"
	if not hashimon_villain.can_breath(cooldown_key) then
		return false
	end

	local dir = normalize_dir(direction)
	local origin = entity_obj:get_pos()
	local spawn_cfg = (profile and profile.breath_spawn) or { forward = 2.5, up = 1.5 }
	local forward = spawn_cfg.forward or 2.5
	local up = spawn_cfg.up or 1.5
	local spawn_pos = {
		x = origin.x + dir.x * forward,
		y = origin.y + up + dir.y * (forward * 0.3),
		z = origin.z + dir.z * forward,
	}

	local obj = core.add_entity(spawn_pos, "hashimon_villain:breath_orb")
	if not obj then
		return false
	end

	local tex = breath_texture(profile)
	local ent = obj:get_luaentity()
	ent.owner = owner_name
	ent.shooter_ref = entity_obj
	ent._dir = dir
	ent._speed = BREATH_SPEED
	ent._damage = BREATH_DAMAGE
	ent._texture = tex
	obj:set_properties({ textures = { tex } })

	hashimon_villain.mark_breath(cooldown_key)
	core.sound_play("fire_fire", { pos = spawn_pos, max_hear_distance = 16 }, true)
	return true
end

function hashimon_villain.dir_toward(from_pos, to_pos)
	return normalize_dir({
		x = to_pos.x - from_pos.x,
		y = to_pos.y - from_pos.y + 0.5,
		z = to_pos.z - from_pos.z,
	})
end

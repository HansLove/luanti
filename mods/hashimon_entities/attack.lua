-- Hashimon blast orb projectile — TNT explosion on impact.

hashimon = hashimon or {}

local BLAST_SPEED = 20
local BLAST_TIMEOUT = 4
local BLAST_COOLDOWN = 3
local ORB_VISUAL_SIZE = 0.35

hashimon._attack_cooldown = hashimon._attack_cooldown or {}
hashimon._has_tnt = core.get_modpath("tnt") ~= nil

if not hashimon._has_tnt then
	core.log("warning", "[hashimon_entities] tnt mod not loaded — blast orbs deal damage only (no block destruction)")
end

local function normalize_dir(dir)
	local len = math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
	if len < 0.001 then
		return { x = 0, y = 0, z = 1 }
	end
	return { x = dir.x / len, y = dir.y / len, z = dir.z / len }
end

local function round_pos(pos)
	return {
		x = math.floor(pos.x + 0.5),
		y = math.floor(pos.y + 0.5),
		z = math.floor(pos.z + 0.5),
	}
end

local function hits_solid_node(pos)
	local node = core.get_node(pos)
	return node.name ~= "air" and node.name ~= "ignore"
end

local function should_hit_entity(self, obj)
	if obj == self.object then
		return false
	end
	if self.shooter_ref and obj == self.shooter_ref then
		return false
	end
	local owner = self.owner and core.get_player_by_name(self.owner)
	if owner and obj == owner then
		return false
	end
	local ent = obj:get_luaentity()
	if not ent then
		return obj:is_player()
	end
	if ent.name == "hashimon_entities:blast_orb" then
		return false
	end
	if ent.name == "hashimon_entities:companion" or ent.name == "hashimon_entities:creature" then
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
		if pointed.type == "object" and pointed.ref then
			if should_hit_entity(self, pointed.ref) then
				local hit_pos = pointed.under
				if not hit_pos then
					hit_pos = pointed.ref:get_pos()
				end
				return hit_pos, "object"
			end
		end
	end
	return nil
end

local function entity_impact_at(self, pos)
	local objs = core.get_objects_inside_radius(pos, 0.8)
	for _, obj in ipairs(objs) do
		if should_hit_entity(self, obj) then
			return obj:get_pos() or pos
		end
	end
	return nil
end

function hashimon.creature_cooldown_key(creature, index)
	if creature and creature.dna and creature.dna ~= "" then
		return creature.dna
	end
	if creature and creature.speciesKey then
		return creature.speciesKey .. ":" .. tostring(index or 0)
	end
	return tostring(index or 0)
end

function hashimon.blast_power_for_creature(creature)
	local stage = (creature and (creature.stage or creature.tier)) or 1
	return math.min(5, 2 + math.floor(stage / 3))
end

function hashimon.get_creature_from_entity(obj)
	if not obj or not obj:get_luaentity() then
		return nil
	end
	local ent = obj:get_luaentity()
	return ent.hashimon_creature or ent.creature
end

function hashimon.can_hashimon_attack(player_name, creature_key)
	hashimon._attack_cooldown[player_name] = hashimon._attack_cooldown[player_name] or {}
	local last = hashimon._attack_cooldown[player_name][creature_key]
	if not last then
		return true
	end
	return (core.get_us_time() / 1000000) - last >= BLAST_COOLDOWN
end

local function mark_attack_used(player_name, creature_key)
	hashimon._attack_cooldown[player_name] = hashimon._attack_cooldown[player_name] or {}
	hashimon._attack_cooldown[player_name][creature_key] = core.get_us_time() / 1000000
end

local function orb_texture_for_creature(creature)
	local hex = hashimon.texture_color_for_creature(creature)
	return "hashimon_placeholder.png^[colorize:#" .. hex .. ":255"
end

local function explode_at(pos, power, owner_name)
	if hashimon._has_tnt and tnt and tnt.boom then
		tnt.boom(pos, {
			radius = power,
			damage_radius = power * 2,
			explode_center = true,
		})
		return
	end

	core.sound_play("tnt_explode", { pos = pos, max_hear_distance = 64 }, true)
	local objs = core.get_objects_inside_radius(pos, power * 2)
	for _, obj in ipairs(objs) do
		if obj:is_player() then
			local pname = obj:get_player_name()
			if pname ~= owner_name then
				obj:punch(obj, 1.0, {
					full_punch_interval = 1.0,
					damage_groups = { fleshy = power * 4 },
				}, nil)
			end
		else
			local ent = obj:get_luaentity()
			if ent and ent.name ~= "hashimon_entities:blast_orb" then
				obj:punch(obj, 1.0, {
					full_punch_interval = 1.0,
					damage_groups = { fleshy = power * 4 },
				}, nil)
			end
		end
	end
end

core.register_entity("hashimon_entities:blast_orb", {
	initial_properties = {
		visual = "sprite",
		textures = { "hashimon_placeholder.png^[colorize:#F97316:255" },
		visual_size = { x = ORB_VISUAL_SIZE, y = ORB_VISUAL_SIZE },
		physical = false,
		collide_with_objects = false,
		collisionbox = { -0.15, -0.15, -0.15, 0.15, 0.15, 0.15 },
		static_save = false,
		glow = 8,
	},

	owner = nil,
	power = 2,
	shooter_ref = nil,
	_dir = nil,
	_speed = BLAST_SPEED,
	_last_pos = nil,
	_age = 0,

	on_activate = function(self, _staticdata, _ds)
		self.object:set_armor_groups({ immortal = 1, fleshy = 0 })
	end,

	explode_at = function(self, pos)
		if self._exploded then
			return
		end
		self._exploded = true
		explode_at(pos, self.power or 2, self.owner)
		self.object:remove()
	end,

	on_step = function(self, dtime)
		self._age = (self._age or 0) + dtime
		if self._age >= BLAST_TIMEOUT then
			self.object:remove()
			return
		end

		local pos = self.object:get_pos()
		if not pos then
			return
		end

		local dir = self._dir or { x = 0, y = 0, z = 1 }
		local speed = self._speed or BLAST_SPEED
		local next_pos = vector.add(pos, vector.multiply(dir, speed * dtime))

		local impact_pos = ray_impact(self, pos, next_pos)
		if impact_pos then
			self:explode_at(impact_pos)
			return
		end

		local entity_hit = entity_impact_at(self, next_pos)
		if entity_hit then
			self:explode_at(entity_hit)
			return
		end

		self.object:set_pos(next_pos)
		self._last_pos = next_pos

		core.add_particlespawner({
			amount = 2,
			time = 0.05,
			minpos = pos,
			maxpos = pos,
			minvel = { x = 0, y = 0, z = 0 },
			maxvel = { x = 0, y = 0, z = 0 },
			minexptime = 0.2,
			maxexptime = 0.4,
			minsize = 0.5,
			maxsize = 1,
			collisiondetection = false,
			texture = self._trail_texture or "fire_basic_flame.png",
		})
	end,
})

function hashimon.launch_blast_from_entity(entity_obj, direction, owner_name, creature, creature_key)
	if not entity_obj or not entity_obj:get_pos() then
		return false, "no_entity"
	end

	creature = creature or hashimon.get_creature_from_entity(entity_obj)
	if not creature then
		return false, "no_creature"
	end

	creature_key = creature_key or hashimon.creature_cooldown_key(creature)
	if not hashimon.can_hashimon_attack(owner_name, creature_key) then
		return false, "cooldown"
	end

	local dir = normalize_dir(direction)
	local origin = entity_obj:get_pos()
	local spawn_pos = {
		x = origin.x + dir.x * 0.6,
		y = origin.y + 0.8,
		z = origin.z + dir.z * 0.6,
	}

	local obj = core.add_entity(spawn_pos, "hashimon_entities:blast_orb")
	if not obj then
		return false, "spawn_failed"
	end

	local ent = obj:get_luaentity()
	local power = hashimon.blast_power_for_creature(creature)
	ent.owner = owner_name
	ent.power = power
	ent.shooter_ref = entity_obj
	ent._dir = dir
	ent._speed = BLAST_SPEED
	ent._last_pos = spawn_pos
	ent._trail_texture = orb_texture_for_creature(creature)
	obj:set_properties({
		textures = { orb_texture_for_creature(creature) },
	})

	core.sound_play("default_fire_flint_and_steel", {
		pos = spawn_pos,
		max_hear_distance = 16,
	}, true)

	mark_attack_used(owner_name, creature_key)

	if hits_solid_node(round_pos(spawn_pos)) then
		ent:explode_at(round_pos(spawn_pos))
	end

	return true
end

local function living_roster_entries(player_name)
	local list = hashimon.get_roster_entities and hashimon.get_roster_entities(player_name) or {}
	local entries = {}
	for index, obj in ipairs(list) do
		if obj and obj:get_luaentity() then
			local creature = hashimon.get_creature_from_entity(obj)
			table.insert(entries, {
				index = index,
				obj = obj,
				creature = creature,
				key = hashimon.creature_cooldown_key(creature, index),
			})
		end
	end
	return entries
end

function hashimon.attack_roster_at_index(player_name, index, direction)
	local entries = living_roster_entries(player_name)
	if #entries == 0 then
		return false, "empty_roster"
	end

	local entry = entries[index]
	if not entry then
		return false, "invalid_index"
	end

	return hashimon.launch_blast_from_entity(entry.obj, direction, player_name, entry.creature, entry.key)
end

function hashimon.attack_nearest_roster(player_name, direction)
	local player = core.get_player_by_name(player_name)
	if not player then
		return false, "no_player"
	end

	local entries = living_roster_entries(player_name)
	if #entries == 0 then
		return false, "empty_roster"
	end

	local ppos = player:get_pos()
	local nearest
	local nearest_dist = math.huge
	for _, entry in ipairs(entries) do
		local epos = entry.obj:get_pos()
		if epos then
			local dx = epos.x - ppos.x
			local dy = epos.y - ppos.y
			local dz = epos.z - ppos.z
			local dist = dx * dx + dy * dy + dz * dz
			if dist < nearest_dist then
				nearest_dist = dist
				nearest = entry
			end
		end
	end

	if not nearest then
		return false, "no_entity"
	end

	return hashimon.launch_blast_from_entity(
		nearest.obj,
		direction,
		player_name,
		nearest.creature,
		nearest.key
	)
end

function hashimon.attack_all_roster(player_name, direction)
	local entries = living_roster_entries(player_name)
	if #entries == 0 then
		return false, "empty_roster"
	end

	local launched = 0
	for i, entry in ipairs(entries) do
		core.after((i - 1) * 0.1, function()
			hashimon.launch_blast_from_entity(
				entry.obj,
				direction,
				player_name,
				entry.creature,
				entry.key
			)
		end)
		launched = launched + 1
	end
	return true, launched
end

function hashimon.try_shift_blast_attack(clicker, entity_obj, creature, owner_name)
	if not clicker or not clicker:is_player() then
		return false
	end
	if not clicker:get_player_control().sneak then
		return false
	end

	local player_name = clicker:get_player_name()
	if owner_name and player_name ~= owner_name then
		return false
	end

	if not owner_name then
		local roster = hashimon.get_roster_entities and hashimon.get_roster_entities(player_name) or {}
		local found = false
		for _, obj in ipairs(roster) do
			if obj == entity_obj then
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end

	local ok, err = hashimon.launch_blast_from_entity(
		entity_obj,
		clicker:get_look_dir(),
		player_name,
		creature
	)
	if not ok and err == "cooldown" then
		core.chat_send_player(player_name, "[Hashimon] Attack on cooldown — wait " .. BLAST_COOLDOWN .. "s.")
	end
	return ok
end

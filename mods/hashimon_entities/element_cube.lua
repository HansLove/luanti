-- Elemental cube projectile — the ranged attack a Hashimon actually throws.
--
-- Design notes (why this is not attack.lua's blast orb):
--   * attack.lua's blast_orb is a *siege* weapon: it calls tnt.boom and eats
--     terrain. That is fine for demolishing, wrong for combat — you cannot
--     shoot at something standing on your own town's wall.
--   * This one is a **cube** (visual = "cube", like voxel_body's parts), it
--     never touches a single node, and everything about it — colour, opacity,
--     damage, speed, knockback, status effect — comes from the creature's
--     Genesis element. A fire Hashimon throws an opaque orange cube of fire;
--     a water one throws a translucent blue cube; ice a pale translucent one;
--     earth a solid brown block; electric a glowing yellow one.
--
-- Two callers: the rider (mount.lua input, LMB while mounted) and the guard AI
-- (defense.lua, when the owner is attacked).

hashimon = hashimon or {}

local BASE_TEXTURE = "hashimon_placeholder.png"
local CUBE_TIMEOUT = 4 -- seconds before an un-hit cube despawns
local CUBE_HIT_RADIUS = 0.9 -- entity sweep radius per step
local SPLASH_RADIUS = 1.6 -- nodes; area damage on impact (no block damage)

-- Element table. `alpha` < 255 makes the cube translucent (agua / hielo / aire
-- read as "made of that stuff" rather than as a painted brick). `slow` is a
-- movement multiplier applied to a hit *player* for `slow_t` seconds; mobs take
-- damage + knockback only (they have no physics_override).
hashimon.ELEMENT_CUBES = {
	fuego = {
		hex = "#F97316", alpha = 255, glow = 13, damage = 6, speed = 22,
		knockback = 3, lift = 2, burn_ticks = 3, burn_damage = 2,
		trail = "fire_basic_flame.png", sound = "fire_flint_and_steel",
	},
	agua = {
		hex = "#3B82F6", alpha = 140, glow = 5, damage = 4, speed = 24,
		knockback = 8, lift = 2, slow = 0.72, slow_t = 2.5,
		trail = "bubble.png", sound = "default_water_footstep",
	},
	hielo = {
		hex = "#BAE6FD", alpha = 170, glow = 8, damage = 5, speed = 26,
		knockback = 2, lift = 1, slow = 0.45, slow_t = 3.0,
		trail = "default_snow.png", sound = "default_snow_footstep",
	},
	tierra = {
		hex = "#92400E", alpha = 255, glow = 0, damage = 7, speed = 16,
		knockback = 2, lift = 1,
		trail = "default_dirt.png", sound = "default_hard_footstep",
	},
	electrico = {
		hex = "#EAB308", alpha = 205, glow = 14, damage = 5, speed = 30,
		knockback = 2, lift = 1, slow = 0.3, slow_t = 1.2,
		trail = "default_mese_crystal_fragment.png", sound = "default_break_glass",
	},
	aire = {
		hex = "#67E8F9", alpha = 110, glow = 6, damage = 3, speed = 28,
		knockback = 11, lift = 6,
		trail = "default_cloud.png", sound = "default_place_node",
	},
}

-- Every other Genesis type (pixel, onda, astro, magia, metal, …) shoots a
-- generic cube painted in its own type colour — no element gets left mute.
local GENERIC_CUBE = {
	alpha = 205, glow = 9, damage = 4, speed = 22, knockback = 3, lift = 2,
	trail = "hashimon_placeholder.png", sound = "default_place_node",
}

local CUBE_ALIASES = {
	fuego = "fuego", fire = "fuego",
	agua = "agua", water = "agua",
	hielo = "hielo", ice = "hielo", nieve = "hielo",
	tierra = "tierra", earth = "tierra",
	electrico = "electrico", ["eléctrico"] = "electrico", electric = "electrico",
	aire = "aire", air = "aire", viento = "aire",
}

hashimon._cube_cooldown = hashimon._cube_cooldown or {} -- [player][key] = t
hashimon._cube_slows = hashimon._cube_slows or {} -- [player_name] = expiry

--- Normalize any element spelling to a cube key, or nil when the element has
--- no dedicated cube (caller then falls back to the generic one).
function hashimon.normalize_cube_element(raw)
	if not raw or raw == "" then
		return nil
	end
	local key = tostring(raw):lower():gsub("%s+", "")
	return CUBE_ALIASES[key] or (hashimon.ELEMENT_CUBES[key] and key) or nil
end

--- Resolve the cube spec for a creature. `override` (QA / mount_element) wins
--- over the creature's own DNA type, exactly like mount profiles do.
function hashimon.element_cube_spec(creature, override)
	local elem = hashimon.normalize_cube_element(override)
	local raw_type = creature and hashimon.type_for_creature
		and hashimon.type_for_creature(creature)
	if not elem then
		elem = hashimon.normalize_cube_element(raw_type)
	end

	local spec = elem and hashimon.ELEMENT_CUBES[elem]
	if spec then
		return spec, elem
	end

	-- Generic cube, painted with the creature's own type colour.
	local hex = (hashimon.texture_color_for_creature
		and hashimon.texture_color_for_creature(creature)) or "A855F7"
	local generic = {}
	for k, v in pairs(GENERIC_CUBE) do
		generic[k] = v
	end
	generic.hex = "#" .. hex
	return generic, (raw_type or "pixel")
end

--- Stage scaling: a stage-1 hatchling pokes, a stage-30 veteran hurts.
--- Kept deliberately flat (×1 → ×2.4) so gear/level never replaces aim.
function hashimon.cube_damage_for(creature, spec)
	local stage = (hashimon.creature_stage and hashimon.creature_stage(creature)) or 1
	local mult = math.min(2.4, 1 + stage * 0.045)
	return math.max(1, math.floor((spec.damage or 4) * mult + 0.5))
end

local function cube_textures(spec)
	local tex = BASE_TEXTURE .. "^[colorize:" .. (spec.hex or "#A855F7") .. ":255"
	if (spec.alpha or 255) < 255 then
		tex = tex .. "^[opacity:" .. math.floor(spec.alpha)
	end
	return { tex, tex, tex, tex, tex, tex }
end

--- World Y the cube leaves from: a bit under the shooter's shoulder line.
--- Exported because callers that *aim* (the guard AI) must aim from here, not
--- from the entity origin, or a tall Hashimon shoots straight over its target.
function hashimon.cube_muzzle_height(entity_obj)
	local origin = entity_obj and entity_obj:get_pos()
	if not origin then
		return nil
	end
	local props = entity_obj:get_properties()
	local box = props and props.collisionbox
	local top = (box and #box >= 6 and box[5]) or 0.8
	return origin.y + math.max(0.6, top * 0.8)
end

--- Centre of an object's body, not its origin. `get_pos()` on a mob or player
--- is at the feet, so measuring hits against it makes a level shot miss over
--- the head of anything shorter than the shooter.
local function body_center(obj)
	local pos = obj and obj:get_pos()
	if not pos then
		return nil
	end
	local props = obj.get_properties and obj:get_properties()
	local box = props and props.collisionbox
	if box and #box >= 6 then
		return { x = pos.x, y = pos.y + (box[2] + box[5]) * 0.5, z = pos.z }
	end
	return { x = pos.x, y = pos.y + 0.9, z = pos.z }
end

local function normalize(dir)
	local len = math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
	if len < 0.001 then
		return { x = 0, y = 0, z = 1 }
	end
	return { x = dir.x / len, y = dir.y / len, z = dir.z / len }
end

local function is_friendly(self, obj)
	if not obj or obj == self.object then
		return true
	end
	if self.shooter_ref and obj == self.shooter_ref then
		return true
	end
	if obj:is_player() then
		local name = obj:get_player_name()
		if name == self.owner then
			return true
		end
		-- The rider of the shooting Hashimon is the owner in every current
		-- path, but a passenger-shot cube must not hit its own carrier either.
		if self.shooter_ref then
			local ent = self.shooter_ref:get_luaentity()
			if ent and ent.rider == name then
				return true
			end
		end
		return false
	end

	local ent = obj:get_luaentity()
	if not ent then
		return true -- carts, items, unknown: never a valid target
	end
	if ent.name == "hashimon_entities:element_cube"
		or ent.name == "hashimon_entities:blast_orb"
		or ent.name == "hashimon_entities:voxel_part" then
		return true
	end
	-- Friendly fire off for the shooter's own collection.
	if ent.owner and ent.owner == self.owner then
		return true
	end
	return false
end

--- Slow / stun a player for a while, then hand movement back. Skipped while
--- mounted: the mount's own physics_override owns the rider there, and fighting
--- over it would strand the player at speed 0.
local function apply_slow(obj, spec, _source_name)
	if not obj or not obj:is_player() or not spec.slow then
		return
	end
	local name = obj:get_player_name()
	if hashimon.mounts and hashimon.mounts[name] then
		return
	end
	local until_t = (core.get_us_time() / 1e6) + (spec.slow_t or 2)
	hashimon._cube_slows[name] = until_t
	obj:set_physics_override({ speed = spec.slow })
	core.after(spec.slow_t or 2, function()
		local p = core.get_player_by_name(name)
		if not p then
			hashimon._cube_slows[name] = nil
			return
		end
		-- Another cube landed later: let that one own the restore.
		if (hashimon._cube_slows[name] or 0) > until_t + 0.01 then
			return
		end
		hashimon._cube_slows[name] = nil
		if hashimon.mounts and hashimon.mounts[name] then
			return
		end
		p:set_physics_override({ speed = 1 })
	end)
end

--- Fire cube afterburn: a few delayed damage ticks, no node ignition (a
--- projectile that sets the world on fire is a griefing tool, not a weapon).
local function apply_burn(obj, spec, source_obj)
	local ticks = spec.burn_ticks or 0
	if ticks <= 0 then
		return
	end
	local dmg = spec.burn_damage or 1
	for i = 1, ticks do
		core.after(i * 1.0, function()
			if not obj or not obj:get_pos() then
				return
			end
			local puncher = (source_obj and source_obj:get_pos() and source_obj) or obj
			obj:punch(puncher, 1.0, {
				full_punch_interval = 1.0,
				damage_groups = { fleshy = dmg },
			}, nil)
			local pos = obj:get_pos()
			if pos then
				core.add_particlespawner({
					amount = 6, time = 0.2,
					minpos = { x = pos.x - 0.3, y = pos.y, z = pos.z - 0.3 },
					maxpos = { x = pos.x + 0.3, y = pos.y + 1.2, z = pos.z + 0.3 },
					minvel = { x = -0.2, y = 0.6, z = -0.2 },
					maxvel = { x = 0.2, y = 1.6, z = 0.2 },
					minexptime = 0.2, maxexptime = 0.5,
					minsize = 1, maxsize = 2.4,
					texture = spec.trail or "fire_basic_flame.png",
					glow = 12,
				})
			end
		end)
	end
end

local function impact_particles(pos, spec)
	core.add_particlespawner({
		amount = 22,
		time = 0.12,
		minpos = { x = pos.x - 0.4, y = pos.y - 0.4, z = pos.z - 0.4 },
		maxpos = { x = pos.x + 0.4, y = pos.y + 0.8, z = pos.z + 0.4 },
		minvel = { x = -2, y = 0.2, z = -2 },
		maxvel = { x = 2, y = 3, z = 2 },
		minacc = { x = 0, y = -4, z = 0 },
		maxacc = { x = 0, y = -6, z = 0 },
		minexptime = 0.2,
		maxexptime = 0.6,
		minsize = 1,
		maxsize = 3,
		texture = spec.trail or BASE_TEXTURE,
		glow = spec.glow or 6,
	})
end

core.register_entity("hashimon_entities:element_cube", {
	initial_properties = {
		visual = "cube",
		visual_size = { x = 0.4, y = 0.4, z = 0.4 },
		textures = {
			BASE_TEXTURE, BASE_TEXTURE, BASE_TEXTURE,
			BASE_TEXTURE, BASE_TEXTURE, BASE_TEXTURE,
		},
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		use_texture_alpha = true,
		backface_culling = false,
		glow = 8,
	},

	owner = nil,
	shooter_ref = nil,
	spec = nil,
	damage = 4,
	_dir = nil,
	_speed = 22,
	_age = 0,
	_spun = 0,

	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1, fleshy = 0 })
	end,

	--- Damage-only impact: splash punch + element effect. Never edits nodes.
	impact = function(self, pos, direct_obj)
		if self._done then
			return
		end
		self._done = true
		local spec = self.spec or GENERIC_CUBE
		local shooter = self.shooter_ref
		local dir = self._dir or { x = 0, y = 0, z = 1 }

		local hit = {}
		if direct_obj then
			table.insert(hit, direct_obj)
		end
		for _, obj in ipairs(core.get_objects_inside_radius(pos, SPLASH_RADIUS)) do
			if obj ~= direct_obj and not is_friendly(self, obj) then
				table.insert(hit, obj)
			end
		end

		for _, obj in ipairs(hit) do
			local puncher = (shooter and shooter:get_pos() and shooter) or obj
			obj:punch(puncher, 1.0, {
				full_punch_interval = 1.0,
				damage_groups = { fleshy = self.damage or spec.damage or 4 },
			}, dir)
			local kb = spec.knockback or 3
			if kb > 0 and obj:get_pos() then
				obj:add_velocity({
					x = dir.x * kb,
					y = (spec.lift or 1) + math.max(0, dir.y) * kb * 0.5,
					z = dir.z * kb,
				})
			end
			apply_slow(obj, spec, self.owner)
			apply_burn(obj, spec, shooter)
		end

		impact_particles(pos, spec)
		core.sound_play(spec.sound or "default_place_node", {
			pos = pos,
			max_hear_distance = 24,
			gain = 0.7,
		}, true)
		self.object:remove()
	end,

	on_step = function(self, dtime)
		self._age = (self._age or 0) + dtime
		if self._age >= CUBE_TIMEOUT then
			self.object:remove()
			return
		end

		local pos = self.object:get_pos()
		if not pos then
			return
		end

		local dir = self._dir or { x = 0, y = 0, z = 1 }
		local speed = self._speed or 22
		local next_pos = vector.add(pos, vector.multiply(dir, speed * dtime))

		-- Nodes stop the cube (and it dies there) but are never dug or burnt.
		for pointed in core.raycast(pos, next_pos, true, false) do
			if pointed.type == "node" then
				self:impact(pointed.under or next_pos, nil)
				return
			end
			if pointed.type == "object" and pointed.ref and not is_friendly(self, pointed.ref) then
				self:impact(pointed.ref:get_pos() or next_pos, pointed.ref)
				return
			end
		end

		-- Radius sweep, measured to each body's centre (see body_center).
		for _, obj in ipairs(core.get_objects_inside_radius(next_pos, CUBE_HIT_RADIUS + 1.2)) do
			if not is_friendly(self, obj) then
				local center = body_center(obj)
				if center then
					local dx, dy, dz = center.x - next_pos.x, center.y - next_pos.y, center.z - next_pos.z
					if math.sqrt(dx * dx + dy * dy + dz * dz) <= CUBE_HIT_RADIUS then
						self:impact(center, obj)
						return
					end
				end
			end
		end

		self.object:set_pos(next_pos)

		-- Tumble: sells "a cube of element", not a floating decal.
		self._spun = (self._spun or 0) + dtime * 6
		self.object:set_rotation({ x = self._spun, y = self._spun * 0.7, z = 0 })

		local spec = self.spec or GENERIC_CUBE
		core.add_particlespawner({
			amount = 3,
			time = 0.06,
			minpos = pos,
			maxpos = pos,
			minvel = { x = -0.2, y = -0.2, z = -0.2 },
			maxvel = { x = 0.2, y = 0.4, z = 0.2 },
			minexptime = 0.15,
			maxexptime = 0.35,
			minsize = 0.6,
			maxsize = 1.6,
			texture = spec.trail or BASE_TEXTURE,
			glow = spec.glow or 6,
		})
	end,
})

--- Per-creature cooldown, shared key space with attack.lua's orb cooldown
--- helper so one creature cannot double-dip by switching attacks.
function hashimon.cube_ready(player_name, key, cooldown)
	hashimon._cube_cooldown[player_name] = hashimon._cube_cooldown[player_name] or {}
	local last = hashimon._cube_cooldown[player_name][key]
	if not last then
		return true
	end
	return (core.get_us_time() / 1e6) - last >= cooldown
end

function hashimon.cube_mark_used(player_name, key)
	hashimon._cube_cooldown[player_name] = hashimon._cube_cooldown[player_name] or {}
	hashimon._cube_cooldown[player_name][key] = core.get_us_time() / 1e6
end

function hashimon.cube_cooldown_left(player_name, key, cooldown)
	local last = (hashimon._cube_cooldown[player_name] or {})[key]
	if not last then
		return 0
	end
	return math.max(0, cooldown - ((core.get_us_time() / 1e6) - last))
end

--- Throw one elemental cube from `entity_obj` along `direction`.
--- opts = { cooldown, key, spawn_height, damage_mult, no_cooldown }
--- Returns true, or false + reason ("cooldown" / "no_creature" / …).
function hashimon.launch_element_cube(entity_obj, direction, owner_name, creature, opts)
	opts = opts or {}
	if not entity_obj or not entity_obj:get_pos() then
		return false, "no_entity"
	end

	creature = creature or (hashimon.get_creature_from_entity
		and hashimon.get_creature_from_entity(entity_obj))
	if not creature then
		return false, "no_creature"
	end

	local ent = entity_obj:get_luaentity()
	local spec, elem = hashimon.element_cube_spec(
		creature,
		opts.element or (ent and ent._mount_element_override)
	)

	local key = opts.key
		or (hashimon.creature_cooldown_key and hashimon.creature_cooldown_key(creature))
		or tostring(entity_obj)
	local cooldown = opts.cooldown or hashimon.CUBE_COOLDOWN or 1.2
	if not opts.no_cooldown and owner_name
		and not hashimon.cube_ready(owner_name, key, cooldown) then
		return false, "cooldown"
	end

	local dir = normalize(direction or { x = 0, y = 0, z = 1 })
	local origin = entity_obj:get_pos()
	local muzzle_y = hashimon.cube_muzzle_height(entity_obj) + (opts.spawn_height or 0)
	local spawn_pos = {
		x = origin.x + dir.x * 1.2,
		y = muzzle_y + dir.y * 0.8,
		z = origin.z + dir.z * 1.2,
	}

	local obj = core.add_entity(spawn_pos, "hashimon_entities:element_cube")
	if not obj then
		return false, "spawn_failed"
	end

	local cube = obj:get_luaentity()
	cube.owner = owner_name
	cube.shooter_ref = entity_obj
	cube.spec = spec
	cube.damage = math.floor(
		hashimon.cube_damage_for(creature, spec) * (opts.damage_mult or 1) + 0.5
	)
	cube._dir = dir
	cube._speed = spec.speed or 22
	obj:set_properties({
		textures = cube_textures(spec),
		glow = spec.glow or 8,
		visual_size = { x = 0.45, y = 0.45, z = 0.45 },
	})

	core.sound_play(spec.sound or "default_place_node", {
		pos = spawn_pos,
		max_hear_distance = 20,
		gain = 0.6,
	}, true)

	if owner_name and not opts.no_cooldown then
		hashimon.cube_mark_used(owner_name, key)
	end

	return true, elem
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	hashimon._cube_cooldown[name] = nil
	hashimon._cube_slows[name] = nil
end)

core.log("action", "[hashimon_entities] Elemental cube projectile registered (damage-only, element-coloured)")

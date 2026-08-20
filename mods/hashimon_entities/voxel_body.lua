-- Procedural voxel body: a Hashimon's own shape, assembled from colored
-- "cube" entities attached to a root part, driven by hashimon_core's
-- dna_compiler (dna -> look -> 5-tone ramp). This is the Luanti-side
-- equivalent of encubation-website's Three.js canine assembly — same DNA,
-- same ramp, same proportions in spirit — realized as native voxel cubes
-- instead of smooth capsule/sphere/cone geometry, since Luanti entities have
-- no built-in parametric primitives beyond "cube".
--
-- Two silhouettes, gated on mining progress (never mined = egg; mined at
-- least once = creature), matching the game's own "identity is inherited,
-- ornament is earned" design: a Hashimon always has a form (Nivel 0), and
-- that form visibly grows up as its owner mines.

hashimon = hashimon or {}

-- Same factor tables as encubation-website/src/lib/creatures/canine.ts
-- (BUILD_FACTOR / SIZE_FACTOR) — keeps proportions DNA-faithful and
-- consistent with the portal's canine, not just its colour.
local BUILD_FACTOR = {
	delicate = 0.70, lean = 0.82, balanced = 1.00, stocky = 1.18,
	muscular = 1.30, bulbous = 1.50, angular = 0.90, round = 1.15,
}
local SIZE_FACTOR = {
	diminutive = 0.55, small = 0.75, medium = 1.00, large = 1.35, huge = 1.70, massive = 2.20,
}

local BASE_TEXTURE = "hashimon_placeholder.png"

local function colorize(hex)
	return BASE_TEXTURE .. "^[colorize:" .. hex .. ":255"
end

-- Decorative child part: no interaction, purely visual.
core.register_entity("hashimon_entities:voxel_part", {
	initial_properties = {
		visual = "cube",
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		backface_culling = true,
	},
})

-- Follow-owner movement (hashimon.step_follow_owner, entities.lua) matches
-- the tamed_follow_owner feel the old wolf companion had. Rolled by hand
-- instead of depending on Creatura's mob framework because that framework
-- assumes one mesh-based mob entity; ours is a rigid composite (root +
-- attached cubes), and attaching already makes every child move with the
-- root for free — only the root needs real motion.
local GRAVITY = -9.81
-- The canine's own "forward" is +X in local space (see spawn_canine). Yaw 0
-- faces +Z in Luanti, so a part built facing +X needs this offset to align
-- automatic_face_movement_dir with the model's actual forward. If a live
-- test shows the body facing sideways/backward, this is the one constant to
-- retune (try 0, 90, 180 or -90).
local FACE_YAW_OFFSET_DEG = 90

-- Root part: the interactive body. Carries creature/owner data and behaves
-- like the sprite/companion entities (nametag, punch = stats, rightclick =
-- attack or stats, follow owner), so switching between render paths is
-- transparent to players and to the rest of the roster/attack code.
core.register_entity("hashimon_entities:voxel_root", {
	initial_properties = {
		visual = "cube",
		physical = true,
		collide_with_objects = false,
		pointable = true,
		static_save = false,
		backface_culling = true,
		collisionbox = { -0.4, -0.4, -0.4, 0.4, 0.4, 0.4 },
		stepheight = 1.1,
		automatic_face_movement_dir = FACE_YAW_OFFSET_DEG,
		automatic_face_movement_max_rotation_per_sec = 300,
	},

	creature = nil,
	owner = nil,
	size_mult = 1.0,
	rideable = false, -- set from hashimon.is_rideable(creature) in spawn_voxel_creature
	rider = nil, -- player name currently riding, or nil

	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1 })
		self.object:set_acceleration({ x = 0, y = GRAVITY, z = 0 })
	end,

	on_step = function(self, _dtime)
		if self.rider then
			hashimon.step_mounted(self)
			return
		end

		hashimon.step_follow_owner(self)
	end,

	on_punch = function(self, puncher)
		if not puncher or not puncher:is_player() then
			return
		end
		hashimon.send_creature_stats(puncher:get_player_name(), self.creature)
	end,

	on_rightclick = function(self, clicker)
		if not clicker or not clicker:is_player() then
			return
		end
		local clicker_name = clicker:get_player_name()

		-- Already riding this one? Right-click again dismounts.
		if self.rider == clicker_name then
			hashimon.dismount(clicker)
			return
		end

		if hashimon.try_shift_blast_attack and
			hashimon.try_shift_blast_attack(clicker, self.object, self.creature, self.owner) then
			return
		end

		-- Only the owner may ride their own Hashimon, once it's grown enough.
		if self.rideable and not self.rider and clicker_name == self.owner then
			if hashimon.mount(clicker, self.object) then
				return
			end
		end

		hashimon.send_creature_stats(clicker_name, self.creature)
	end,
})

--- Spawn one cube part and (if parent given) attach it.
--- offset is in node-space (same units as visual_size); set_attach wants ×10.
local function spawn_part(entity_name, pos_world, parent, offset, size, hex)
	local obj = core.add_entity(pos_world, entity_name)
	if not obj then
		return nil
	end
	local tex = colorize(hex)
	obj:set_properties({
		textures = { tex, tex, tex, tex, tex, tex },
		visual_size = size,
	})
	if parent then
		obj:set_attach(parent, "", {
			x = offset.x * 10,
			y = offset.y * 10,
			z = offset.z * 10,
		}, { x = 0, y = 0, z = 0 })
	end
	return obj
end

local function spawn_child(pos_world, parent, offset, size, hex)
	return spawn_part("hashimon_entities:voxel_part", pos_world, parent, offset, size, hex)
end

local function spawn_root(pos_world, size, hex, size_mult)
	local obj = spawn_part("hashimon_entities:voxel_root", pos_world, nil, { x = 0, y = 0, z = 0 }, size, hex)
	if obj then
		local h = 0.4 * (size_mult or 1.0) -- half-extent, matches the default collisionbox scaled by size
		obj:set_properties({ collisionbox = { -h, -h, -h, h, h, h } })
	end
	return obj
end

-- ---------------------------------------------------------------------------
-- Egg silhouette — three stacked cubes, tapered like an egg profile.
-- Colored top(highlight) -> mid(base) -> bottom(shadow), echoing the
-- portal's vertical gradient without needing per-pixel texture painting
-- (Luanti mods can't rasterize canvases; solid-color cube faces are the
-- native voxel equivalent).
-- ---------------------------------------------------------------------------

local function v(x, y, z) return { x = x, y = y, z = z } end
local function scale3(a, m) return v(a.x * m, a.y * m, a.z * m) end

local function spawn_egg(pos_world, ramp, size_mult)
	local root = spawn_root(pos_world, scale3(v(0.55, 0.35, 0.55), size_mult), ramp.base.hex, size_mult)
	if not root then
		return nil
	end
	spawn_child(pos_world, root, scale3(v(0, 0.32, 0), size_mult),
		scale3(v(0.4, 0.28, 0.4), size_mult), ramp.highlight.hex)
	spawn_child(pos_world, root, scale3(v(0, -0.3, 0), size_mult),
		scale3(v(0.42, 0.26, 0.42), size_mult), ramp.shadow.hex)
	-- A faint accent band, hinting the creature waiting inside.
	spawn_child(pos_world, root, scale3(v(0, 0.02, 0), size_mult),
		scale3(v(0.58, 0.06, 0.58), size_mult), ramp.accent.hex)
	return root
end

-- ---------------------------------------------------------------------------
-- Canine silhouette — body/head/snout/eyes/ears/legs/tail, same colour zones
-- as encubation-website/src/lib/creatures/canine.ts's PartDescriptor map.
--
-- `build` (BUILD_FACTOR) fattens/thins the body, legs and tail cross-section
-- without changing the skeleton's reach — a "delicate" and a "bulbous"
-- Hashimon stand on the same-spaced legs but look thin vs. stocky.
-- `size` (SIZE_FACTOR) scales the whole creature uniformly, sizes and
-- offsets alike, so "diminutive" and "massive" are genuinely different
-- silhouettes, not just a stats difference.
-- ---------------------------------------------------------------------------

local function spawn_canine(pos_world, ramp, girth_mult, size_mult)
	local g, s = girth_mult, size_mult
	local root = spawn_root(pos_world, v(0.9 * s, 0.4 * g * s, 0.4 * g * s), ramp.base.hex, s)
	if not root then
		return nil
	end

	-- Head + snout + nose tip
	spawn_child(pos_world, root, scale3(v(0.55, 0.25, 0), s),
		scale3(v(0.35, 0.35, 0.35), s), ramp.highlight.hex)
	spawn_child(pos_world, root, scale3(v(0.78, 0.18, 0), s),
		scale3(v(0.18, 0.15, 0.15), s), ramp.shadow.hex)
	spawn_child(pos_world, root, scale3(v(0.89, 0.15, 0), s),
		scale3(v(0.06, 0.06, 0.06), s), ramp.accent.hex)

	-- Eyes (accent, always — see spec: the gaze always carries accent)
	spawn_child(pos_world, root, scale3(v(0.68, 0.3, 0.15), s),
		scale3(v(0.06, 0.06, 0.06), s), ramp.accent.hex)
	spawn_child(pos_world, root, scale3(v(0.68, 0.3, -0.15), s),
		scale3(v(0.06, 0.06, 0.06), s), ramp.accent.hex)

	-- Ears (base + accent tip)
	for _, z in ipairs({ 0.12, -0.12 }) do
		spawn_child(pos_world, root, scale3(v(0.45, 0.42, z), s),
			scale3(v(0.12, 0.18, 0.08), s), ramp.base.hex)
		spawn_child(pos_world, root, scale3(v(0.45, 0.53, z), s),
			scale3(v(0.08, 0.06, 0.06), s), ramp.accent.hex)
	end

	-- Legs (base, girth-scaled thickness) + paws (shadow)
	for _, x in ipairs({ 0.32, -0.32 }) do
		for _, z in ipairs({ 0.16, -0.16 }) do
			spawn_child(pos_world, root, scale3(v(x, -0.35, z), s),
				v(0.1 * g * s, 0.35 * s, 0.1 * g * s), ramp.base.hex)
			spawn_child(pos_world, root, scale3(v(x, -0.55, z), s),
				scale3(v(0.12, 0.08, 0.12), s), ramp.shadow.hex)
		end
	end

	-- Tail (base) + tip (accent)
	spawn_child(pos_world, root, scale3(v(-0.65, 0.12, 0), s),
		v(0.35 * s, 0.12 * g * s, 0.12 * g * s), ramp.base.hex)
	spawn_child(pos_world, root, scale3(v(-0.9, 0.16, 0), s),
		scale3(v(0.1, 0.1, 0.1), s), ramp.accent.hex)

	-- Markings: a band along the back and a matching one on the chest.
	spawn_child(pos_world, root, scale3(v(0, 0.22, 0), s),
		scale3(v(0.85, 0.06, 0.42), s), ramp.marking.hex)
	spawn_child(pos_world, root, scale3(v(0.2, -0.05, 0), s),
		scale3(v(0.1, 0.28, 0.32), s), ramp.marking.hex)

	return root
end

-- ---------------------------------------------------------------------------
-- Public entry point
-- ---------------------------------------------------------------------------

--- A creature that has never mined a share is still an egg. Once it has
--- (stage/tier >= 1), it has hatched and shows its full form.
function hashimon.creature_stage(creature)
	return (creature and (creature.stage or creature.tier)) or 0
end

function hashimon.is_egg_stage(creature)
	return hashimon.creature_stage(creature) < 1
end

--- Build a DNA-correct voxel body at pos_world for the given creature and
--- wire it up exactly like the sprite/companion entities (nametag, owner,
--- punch/rightclick). Returns the root ObjectRef, or nil if look/ramp
--- couldn't be compiled (caller should fall back to sprite/colorize).
function hashimon.spawn_voxel_creature(pos_world, creature, owner)
	if not creature or not creature.dna then
		return nil
	end
	local element_type = hashimon.type_for_creature(creature)
	local look = hashimon.compile_look(creature.dna, element_type)
	if not look then
		return nil
	end
	local ramp = hashimon.derive_color_ramp(look)
	local girth_mult = BUILD_FACTOR[look.build] or 1.0
	local size_mult = SIZE_FACTOR[look.size] or 1.0

	local root
	if hashimon.is_egg_stage(creature) then
		root = spawn_egg(pos_world, ramp, size_mult)
	else
		root = spawn_canine(pos_world, ramp, girth_mult, size_mult)
	end
	if not root then
		return nil
	end

	local ent = root:get_luaentity()
	if ent then
		ent.creature = creature
		ent.owner = owner
		ent.size_mult = size_mult
		ent.rideable = hashimon.is_rideable and hashimon.is_rideable(creature) or false
	end
	root:set_nametag_attributes({
		text = hashimon.nametag_for_creature(creature),
		color = "#E0E7FF",
	})

	return root
end

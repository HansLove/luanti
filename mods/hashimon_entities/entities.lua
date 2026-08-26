-- Shared roster helpers, sprite fallback entity, and spawn logic.

hashimon = hashimon or {}

hashimon.use_companion = false
hashimon._companion_queue = {}

local modpath = core.get_modpath("hashimon_entities")
local species_map = {}

do
	local f = io.open(modpath .. "/species.json", "r")
	if f then
		local raw = f:read("*a")
		f:close()
		local ok, parsed = pcall(core.parse_json, raw)
		if ok and type(parsed) == "table" then
			species_map = parsed
		else
			core.log("warning", "[hashimon_entities] Could not parse species.json")
		end
	end
end

local TYPE_COLORS = {
	pixel = "A855F7",
	fuego = "F97316",
	agua = "3B82F6",
	onda = "14B8A6",
	electrico = "EAB308",
	["eléctrico"] = "EAB308", -- accented spelling, matches compiler.ts TYPES; species.json genesis_electrico uses this
	tierra = "92400E",
	aire = "67E8F9",
	astro = "6366F1",
	sueno = "C084FC",
	["sueño"] = "C084FC",
	magia = "EC4899",
	metal = "94A3B8",
	hongo = "84CC16",
	mental = "F472B6",
	vegetal = "22C55E",
	espiritu = "5EEAD4",
	["espíritu"] = "5EEAD4",
	vacio = "312E81",
	["vacío"] = "312E81",
}

local GRID_SPACING = 3
local player_entities = {}
local player_spawn_center = {}

-- Follow-owner movement shared by every roster entity (sprite/mesh fallback
-- here, procedural voxel body in voxel_body.lua). Straight-line steering
-- toward the owner, matching the old wolf companion's feel.
local FOLLOW_STOP_DISTANCE = 3 -- nodes; stop this close to the owner
local FOLLOW_SPEED = 3.5 -- nodes/sec
local GRAVITY = -9.81

function hashimon.step_follow_owner(self)
	if not self.owner then
		return
	end
	local owner_obj = core.get_player_by_name(self.owner)
	local vel = self.object:get_velocity()
	if not owner_obj or not owner_obj:is_player() then
		self.object:set_velocity({ x = 0, y = vel.y, z = 0 })
		return
	end

	local mypos = self.object:get_pos()
	local ownerpos = owner_obj:get_pos()
	local dx = ownerpos.x - mypos.x
	local dz = ownerpos.z - mypos.z
	local dist = math.sqrt(dx * dx + dz * dz)

	if dist > FOLLOW_STOP_DISTANCE then
		local speed = math.min(FOLLOW_SPEED, dist * 0.6)
		self.object:set_velocity({
			x = (dx / dist) * speed,
			y = vel.y,
			z = (dz / dist) * speed,
		})
	else
		self.object:set_velocity({ x = 0, y = vel.y, z = 0 })
	end
end

function hashimon.type_for_creature(creature)
	local entry = species_map[creature.speciesKey]
	if entry and entry.type then
		return entry.type
	end
	return "pixel"
end

function hashimon.texture_color_for_creature(creature)
	local elem = hashimon.type_for_creature(creature)
	return TYPE_COLORS[elem] or "888888"
end

--- Recolour a creature's body texture from its DNA.
---
--- The element is NOT consulted. This used to return a flat
--- "[colorize:<element colour>:180", which painted 70% of a solid element hue
--- over every pixel — every Water Hashimon came out the same blue, and the eyes,
--- muzzle and fur shading painted into the texture were flattened away.
--- hashimon.texture_mod_from_ramp uses [colorizehsl, which preserves luminance.
---
--- Falls back to the flat element tint only when the DNA compiler is unavailable
--- or the DNA is unusable, so a creature is never left untinted.
function hashimon.texture_mod_for_creature(creature)
	if creature and creature.dna and hashimon.compile_look and hashimon.texture_mod_from_ramp then
		local look = hashimon.compile_look(creature.dna, hashimon.type_for_creature(creature))
		if look then
			return hashimon.texture_mod_from_ramp(hashimon.derive_color_ramp(look))
		end
	end
	return "^[colorize:#" .. hashimon.texture_color_for_creature(creature) .. ":180"
end

--- Stage-driven size multiplier, where 1.0 means "the size the source mob was
--- authored at" (Animalia meshes are built for visual_size 10).
---
--- The old curve was 0.5 + stage*0.08 floored at 0.6, so a stage-1 creature
--- rendered at 60% of a real wolf — and once build/size traits multiplied on top
--- it could reach 38%. Everything looked like a toy. This curve starts a hair
--- under native size and grows from there.
function hashimon.visual_size_for_creature(creature)
	local stage = creature.stage or creature.tier or 1
	return math.max(0.95, math.min(2.6, 0.9 + stage * 0.07))
end

function hashimon.companion_visual_size(creature)
	local scale = hashimon.visual_size_for_creature(creature)
	local base = 10
	return { x = base * scale, y = base * scale }
end

function hashimon.wolf_texture_index(creature)
	local dna = creature.dna or "0"
	local n = 0
	for i = 1, math.min(#dna, 8) do
		n = n + dna:byte(i)
	end
	return (n % 4) + 1
end

function hashimon.nametag_for_creature(creature)
	local name = creature.name or creature.speciesKey or "Hashimon"
	local stage = creature.stage or 1
	return name .. " ★" .. tostring(stage)
end

function hashimon.send_creature_stats(player_name, creature)
	if not creature then
		return
	end
	local bits = (creature.pow and creature.pow.bestShareBits) or creature.bits or 0
	core.chat_send_player(player_name, string.format(
		"[Hashimon] %s — species: %s, DNA: %s..., bits: %d",
		creature.name or creature.speciesKey or "?",
		creature.speciesKey or "?",
		(creature.dna or "????"):sub(1, 8),
		bits
	))
end

function hashimon.enqueue_companion_setup(owner, creature)
	table.insert(hashimon._companion_queue, {
		owner = owner,
		creature = creature,
	})
end

function hashimon.dequeue_companion_setup()
	return table.remove(hashimon._companion_queue, 1)
end

function hashimon.apply_companion_visuals(self, creature)
	if not creature then
		return
	end
	self.hashimon_creature = creature
	local tex_idx = hashimon.wolf_texture_index(creature)
	if self.set_texture then
		self:set_texture(tex_idx, self.textures)
	end
	self.object:set_texture_mod(hashimon.texture_mod_for_creature(creature))
	self.object:set_properties({
		visual_size = hashimon.companion_visual_size(creature),
	})
	self.object:set_nametag_attributes({
		text = hashimon.nametag_for_creature(creature),
		color = "#E0E7FF",
	})
end

local function spawn_center_for(player_name)
	local cached = player_spawn_center[player_name]
	if cached then
		return cached
	end
	local player = core.get_player_by_name(player_name)
	if player then
		local p = player:get_pos()
		cached = {
			x = math.floor(p.x + 0.5),
			y = math.floor(p.y + 0.5),
			z = math.floor(p.z + 0.5),
		}
	else
		cached = { x = 0, y = 20, z = 0 }
	end
	player_spawn_center[player_name] = cached
	return cached
end

local function grid_pos(index, center)
	local row = math.floor((index - 1) / 5)
	local col = (index - 1) % 5
	return {
		x = center.x + (col - 2) * GRID_SPACING,
		y = center.y,
		z = center.z + row * GRID_SPACING,
	}
end

function hashimon.get_roster_entities(player_name)
	return player_entities[player_name] or {}
end

--- Register an already-spawned entity into a player's roster, so it
--- participates in roster-based commands (attack, /hashimon dna) and gets
--- cleaned up on the next resync. For dev spawn paths that build the entity
--- by hand instead of going through spawn_roster.
function hashimon.register_roster_entity(player_name, obj)
	if not obj then
		return
	end
	player_entities[player_name] = player_entities[player_name] or {}
	table.insert(player_entities[player_name], obj)
end

function hashimon.clear_player_entities(player_name)
	local list = player_entities[player_name]
	if not list then
		return
	end
	for _, ref in ipairs(list) do
		if ref and ref:get_luaentity() then
			ref:remove()
		end
	end
	player_entities[player_name] = {}
	player_spawn_center[player_name] = nil
	hashimon._companion_queue = {}
end

--- Spawn one creature at pos, trying each render tier in order so a Hashimon
--- never appears as nothing:
---   1. Premium GLB (hashimon_media registry — optional art form)
---   2. Canonical morphology (Creatura rigged body + DNA phenotype)
---   3. Procedural voxel body (DNA colour + shape)
---   4. Sprite + colorize (last-resort safety net)
local function spawn_creature_entity(pos, creature, owner)
	local media = hashimon.resolve_creature_media and hashimon.resolve_creature_media(creature)
	if media then
		local obj = core.add_entity(pos, "hashimon_entities:creature")
		if obj then
			local ent = obj:get_luaentity()
			if ent then
				ent:setup(creature, owner)
			end
			return obj
		end
	end

	if hashimon.spawn_morph_creature then
		local obj = hashimon.spawn_morph_creature(pos, creature, owner)
		if obj then
			return obj
		end
	end

	if hashimon.spawn_voxel_creature then
		local obj = hashimon.spawn_voxel_creature(pos, creature, owner)
		if obj then
			return obj
		end
	end

	local obj = core.add_entity(pos, "hashimon_entities:creature")
	if obj then
		local ent = obj:get_luaentity()
		if ent then
			ent:setup(creature, owner)
		end
	end
	return obj
end

function hashimon.spawn_roster(player_name, roster)
	hashimon.clear_player_entities(player_name)
	player_entities[player_name] = {}

	if #roster == 0 then
		core.chat_send_player(player_name, "[Hashimon] Roster is empty — use /hashimon starter")
		return
	end

	local center = spawn_center_for(player_name)

	for i, creature in ipairs(roster) do
		local pos = grid_pos(i, center)
		local obj = spawn_creature_entity(pos, creature, player_name)
		if obj then
			table.insert(player_entities[player_name], obj)
		end
	end

	core.chat_send_player(player_name, "[Hashimon] Spawned " .. #roster .. " creature(s) nearby.")
end

-- Sprite fallback when Animalia/Creatura are not loaded.
core.register_entity("hashimon_entities:creature", {
	initial_properties = {
		visual = "upright_sprite",
		textures = { "hashimon_placeholder.png" },
		physical = true,
		collide_with_objects = false,
		collisionbox = { -0.4, -0.4, -0.4, 0.4, 0.4, 0.4 },
		stepheight = 1.1,
		static_save = false,
	},

	creature = nil,
	owner = nil,

	on_activate = function(self, _staticdata, _ds)
		self.object:set_armor_groups({ immortal = 1 })
		self.object:set_acceleration({ x = 0, y = GRAVITY, z = 0 })
	end,

	on_step = function(self, _dtime)
		hashimon.step_follow_owner(self)
	end,

	setup = function(self, creature, owner)
		self.creature = creature
		self.owner = owner
		local size = hashimon.visual_size_for_creature(creature)

		-- A registered 3D model (Meshy-generated, dropped into hashimon_media/
		-- or bundled with a mod) always wins over the sprite/colorize fallback.
		-- See hashimon_core/media.lua for how creature.dna resolves here.
		local media = hashimon.resolve_creature_media and hashimon.resolve_creature_media(creature)
		if media then
			self.object:set_properties({
				visual = "mesh",
				mesh = media.mesh,
				textures = media.textures,
				visual_size = { x = size, y = size },
			})
		else
			local hex = hashimon.texture_color_for_creature(creature)
			self.object:set_properties({
				visual = "upright_sprite",
				textures = { "hashimon_placeholder.png^[colorize:#" .. hex .. ":255" },
				visual_size = { x = size, y = size },
			})
		end

		self.object:set_nametag_attributes({
			text = hashimon.nametag_for_creature(creature),
			color = "#E0E7FF",
		})
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
		if hashimon.try_shift_blast_attack(clicker, self.object, self.creature, self.owner) then
			return
		end
		hashimon.send_creature_stats(clicker:get_player_name(), self.creature)
	end,
})

hashimon.register_roster_callback(function(player_name, roster)
	hashimon.spawn_roster(player_name, roster)
end)

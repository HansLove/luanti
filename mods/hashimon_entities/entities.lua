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
	["eléctrico"] = "EAB308", -- compiler.ts's TYPES/ELEMENT_PALETTES key (with accent); species.json genesis_electrico uses this
	tierra = "92400E",
	aire = "67E8F9",
	astro = "6366F1",
	sueno = "C084FC",
	magia = "EC4899",
	metal = "94A3B8",
	hongo = "84CC16",
	mental = "F472B6",
}

local GRID_SPACING = 3
local player_entities = {}
local player_spawn_center = {}

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

function hashimon.texture_mod_for_creature(creature)
	return "^[colorize:#" .. hashimon.texture_color_for_creature(creature) .. ":180"
end

function hashimon.visual_size_for_creature(creature)
	local stage = creature.stage or creature.tier or 1
	local scale = math.max(0.6, math.min(2.5, 0.5 + stage * 0.08))
	return scale
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
---   1. Custom 3D media (Meshy/Blender GLB, via hashimon_core's media registry)
---   2. Procedural voxel body (DNA-correct colour + shape, this mod)
---   3. Sprite + colorize (last-resort safety net)
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
		physical = false,
		collide_with_objects = false,
		static_save = false,
	},

	creature = nil,
	owner = nil,

	on_activate = function(self, _staticdata, _ds)
		self.object:set_armor_groups({ immortal = 1 })
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

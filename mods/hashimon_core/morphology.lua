-- Hashimon Morphology Compiler (Luanti)
-- DNA + species + generation -> MorphologyDescriptor for canonical Creatura bodies.
-- Keeps parity with encubation-website/src/lib/compiler.ts trait lists.

hashimon = hashimon or {}

hashimon._body_registry = hashimon._body_registry or {}

local modpath_entities = core.get_modpath("hashimon_entities")
local species_map = {}

if modpath_entities then
	local f = io.open(modpath_entities .. "/species.json", "r")
	if f then
		local raw = f:read("*a")
		f:close()
		local ok, parsed = pcall(core.parse_json, raw)
		if ok and type(parsed) == "table" then
			species_map = parsed
		end
	end
end

local ARCHETYPES = {
	"canine", "feline", "ursine", "avian", "aquatic", "reptilian", "arachnid",
	"mollusk", "humanoid", "construct", "celestial", "spectral", "fungal",
	"crystalline", "amorphous", "hybrid",
}

local SIGNATURE_FEATURES = {
	"none", "crown", "wings", "horns", "tail", "aura", "gemstone", "appendages",
}

local BUILD_SCALE = {
	delicate = 0.85, lean = 0.92, balanced = 1.0, stocky = 1.08,
	muscular = 1.12, bulbous = 1.18, angular = 0.95, round = 1.05,
}

local SIZE_SCALE = {
	diminutive = 0.75, small = 0.88, medium = 1.0, large = 1.15, huge = 1.3, massive = 1.5,
}

-- G0 genesis pools — only bodies with registered skeletons in hashimon_bodies.
local G0_POOLS = {
	fuego = { "canine_wolf", "dragon_wyvern" },
	agua = { "canine_wolf" },
	aire = { "avian_bat", "canine_wolf" },
	tierra = { "canine_wolf" },
	["eléctrico"] = { "canine_wolf", "avian_bat" },
	electrico = { "canine_wolf", "avian_bat" },
	pixel = { "canine_wolf" },
	onda = { "canine_wolf", "avian_bat" },
	astro = { "dragon_wyvern", "canine_wolf" },
	["sueño"] = { "canine_wolf" },
	sueno = { "canine_wolf" },
	magia = { "dragon_wyvern", "avian_bat" },
	metal = { "canine_wolf" },
	hongo = { "canine_wolf" },
	mental = { "avian_bat", "canine_wolf" },
	vegetal = { "canine_wolf" },
	["espíritu"] = { "avian_bat", "canine_wolf" },
	espiritu = { "avian_bat", "canine_wolf" },
	["vacío"] = { "dragon_wyvern", "canine_wolf" },
	vacio = { "dragon_wyvern", "canine_wolf" },
}

local ARCHETYPE_DEFAULT_BODY = {
	canine = "canine_wolf",
	feline = "canine_wolf",
	ursine = "canine_wolf",
	avian = "avian_bat",
	aquatic = "canine_wolf",
	reptilian = "dragon_wyvern",
	arachnid = "canine_wolf",
	mollusk = "canine_wolf",
	humanoid = "canine_wolf",
	construct = "canine_wolf",
	celestial = "dragon_wyvern",
	spectral = "avian_bat",
	fungal = "canine_wolf",
	crystalline = "dragon_wyvern",
	amorphous = "avian_bat",
	hybrid = "canine_wolf",
}

local function dna_pick(dna, position, length, list)
	local span = 16 ^ length
	local w = tonumber(dna:sub(position, position + length - 1), 16) or 0
	local i = math.floor((w / span) * #list)
	if i > #list - 1 then i = #list - 1 end
	if i < 0 then i = 0 end
	return list[i + 1]
end

function hashimon.register_body(def)
	if type(def) ~= "table" or type(def.id) ~= "string" then
		return false
	end
	hashimon._body_registry[def.id] = def
	return true
end

function hashimon.get_body(body_id)
	return hashimon._body_registry[body_id]
end

function hashimon.list_bodies()
	local ids = {}
	for id in pairs(hashimon._body_registry) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

function hashimon.creature_generation(creature)
	if not creature then
		return 0
	end
	if creature.generation ~= nil then
		return creature.generation
	end
	if creature.speciesKey and creature.speciesKey:match("^genesis_") then
		return 0
	end
	if creature.provenance == "starter" then
		return 0
	end
	return 1
end

local function species_entry(creature)
	if not creature or not creature.speciesKey then
		return nil
	end
	return species_map[creature.speciesKey]
end

local function pick_archetype(dna)
	return dna_pick(dna, 35, 2, ARCHETYPES)
end

local function pick_signature(dna)
	return dna_pick(dna, 51, 1, SIGNATURE_FEATURES)
end

local function filter_registered(pool)
	local out = {}
	for _, id in ipairs(pool) do
		if hashimon._body_registry[id] then
			table.insert(out, id)
		end
	end
	return out
end

local function pick_body_id(creature, dna, element_type, generation)
	local entry = species_entry(creature)
	if entry and entry.skeleton and hashimon._body_registry[entry.skeleton] then
		return entry.skeleton
	end
	if entry and entry.bodyFamily then
		for id, body in pairs(hashimon._body_registry) do
			if body.family == entry.bodyFamily then
				return id
			end
		end
	end

	local pool
	if generation <= 0 then
		pool = G0_POOLS[element_type] or { "canine_wolf" }
	else
		local archetype = pick_archetype(dna)
		local preferred = ARCHETYPE_DEFAULT_BODY[archetype] or "canine_wolf"
		pool = { preferred, "canine_wolf", "avian_bat", "dragon_wyvern" }
	end

	pool = filter_registered(pool)
	if #pool == 0 then
		return nil
	end

	-- Reserved nibble [8] picks variant within pool when multiple skeletons allowed.
	if #pool > 1 then
		local idx = tonumber(dna:sub(8, 8), 16) or 0
		return pool[(idx % #pool) + 1]
	end
	return pool[1]
end

local function resolve_attachments(signature, element_type, look, stage)
	local attachments = {}
	if signature == "horns" or signature == "crown" then
		table.insert(attachments, "horns")
	elseif signature == "wings" then
		table.insert(attachments, "wings")
	elseif signature == "tail" and (element_type == "fuego" or element_type == "eléctrico" or element_type == "electrico") then
		table.insert(attachments, "tail_glow")
	elseif signature == "gemstone" or signature == "aura" then
		table.insert(attachments, "aura")
	end
	if look and look.markings and look.markings ~= "none" then
		table.insert(attachments, "markings")
	end
	if stage >= 8 and (look.material == "crystal" or look.material == "metal") then
		table.insert(attachments, "aura")
	end
	return attachments
end

function hashimon.morph_visual_size(creature, look, body_def)
	local stage_scale = hashimon.visual_size_for_creature(creature)
	local build = BUILD_SCALE[look.build or "balanced"] or 1.0
	local size = SIZE_SCALE[look.size or "medium"] or 1.0
	local base = (body_def and body_def.visual_size_base) or 10
	local s = base * stage_scale * build * size
	return { x = s, y = s }
end

function hashimon.morph_texture_index(creature)
	return hashimon.wolf_texture_index(creature)
end

--- Compile full morphology descriptor for a roster creature.
--- Returns nil if look/body cannot be resolved.
function hashimon.compile_morphology(creature)
	if not creature or not creature.dna then
		return nil
	end
	local element_type = hashimon.type_for_creature(creature)
	local look = hashimon.compile_look(creature.dna, element_type)
	if not look then
		return nil
	end
	local ramp = hashimon.derive_color_ramp(look)
	local generation = hashimon.creature_generation(creature)
	local body_id = pick_body_id(creature, creature.dna, element_type, generation)
	local body_def = body_id and hashimon.get_body(body_id)
	if not body_def then
		return nil
	end

	local stage = hashimon.creature_stage(creature)
	local signature = pick_signature(creature.dna)
	local archetype = pick_archetype(creature.dna)

	return {
		body_id = body_id,
		family = body_def.family,
		archetype = archetype,
		signature = signature,
		generation = generation,
		look = look,
		ramp = ramp,
		texture_index = hashimon.morph_texture_index(creature),
		texture_mod = "^[colorize:" .. ramp.base.hex .. ":120",
		element_mod = hashimon.texture_mod_for_creature(creature),
		visual_size = hashimon.morph_visual_size(creature, look, body_def),
		attachments = resolve_attachments(signature, element_type, look, stage),
		aura = stage >= 5 or signature == "aura" or look.material == "crystal",
		stage = stage,
		capabilities = body_def.capabilities or {},
	}
end

function hashimon.morphology_available()
	return core.get_modpath("creatura")
		and core.get_modpath("animalia")
		and next(hashimon._body_registry) ~= nil
end

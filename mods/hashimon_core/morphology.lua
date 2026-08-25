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

-- Element pools. The element narrows WHICH bodies are plausible; the DNA picks
-- one within that pool. That is deliberately NOT "element determines body" —
-- every pool holds several families, so two Fire Hashimon usually differ in
-- silhouette (see ADN_PROPIEDAD_TEORIA_DE_JUEGO.md §7: type and body are
-- independent axes).
--
-- Unregistered ids are filtered out at pick time (filter_registered), so listing
-- an optional body like dragon_wyvern is safe when draconis is absent.
--
-- NOTE: the rarity policy (which bodies Genesis may roll vs. which are reserved
-- for Natural/Bitcoin-seeded births) is still undecided — see §3 of the
-- morphology discussion. These pools preserve the previous policy (wyvern
-- already reachable from fuego/astro/magia/vacío) and only fix the diversity
-- collapse. Revisit here once that decision lands.
local G0_POOLS = {
	fuego = { "canine_wolf", "feline_cat", "canine_fox", "dragon_wyvern" },
	agua = { "amphibian_frog", "rodent_rat", "feline_cat", "canine_wolf" },
	aire = { "avian_bat", "avian_owl", "avian_songbird", "feline_cat" },
	tierra = { "ursine_bear", "equine_horse", "canine_wolf", "rodent_rat" },
	["eléctrico"] = { "rodent_rat", "feline_cat", "canine_fox", "avian_bat" },
	electrico = { "rodent_rat", "feline_cat", "canine_fox", "avian_bat" },
	pixel = { "feline_cat", "rodent_rat", "canine_fox", "avian_songbird" },
	onda = { "avian_songbird", "amphibian_frog", "canine_fox", "avian_bat" },
	astro = { "avian_owl", "equine_horse", "dragon_wyvern", "feline_cat" },
	["sueño"] = { "avian_owl", "feline_cat", "amphibian_frog", "avian_bat" },
	sueno = { "avian_owl", "feline_cat", "amphibian_frog", "avian_bat" },
	magia = { "avian_owl", "feline_cat", "dragon_wyvern", "avian_bat" },
	metal = { "ursine_bear", "equine_horse", "canine_wolf", "rodent_rat" },
	hongo = { "amphibian_frog", "rodent_rat", "ursine_bear", "canine_fox" },
	mental = { "avian_owl", "feline_cat", "rodent_rat", "avian_bat" },
	vegetal = { "amphibian_frog", "ursine_bear", "canine_fox", "avian_songbird" },
	["espíritu"] = { "avian_bat", "avian_owl", "feline_cat", "canine_fox" },
	espiritu = { "avian_bat", "avian_owl", "feline_cat", "canine_fox" },
	["vacío"] = { "avian_bat", "dragon_wyvern", "rodent_rat", "avian_owl" },
	vacio = { "avian_bat", "dragon_wyvern", "rodent_rat", "avian_owl" },
}

-- Archetype -> candidate bodies (DNA picks within). Previously this collapsed
-- 9 of 16 archetypes onto canine_wolf, which is why every Hashimon rendered as
-- a wolf regardless of its compiled archetype.
--
-- arachnid / mollusk / humanoid / construct have no faithful skeleton in the
-- MIT stack (Animalia + Draconis). They map to the nearest available silhouette
-- rather than to wolf; real bodies for them need the dmobs tier (golem, orc,
-- wasp — CC BY-SA 3.0, licence decision pending) or a Meshy/procedural body.
local ARCHETYPE_BODY_POOLS = {
	canine = { "canine_wolf", "canine_fox" },
	feline = { "feline_cat" },
	ursine = { "ursine_bear" },
	avian = { "avian_bat", "avian_owl", "avian_songbird" },
	aquatic = { "amphibian_frog" }, -- placeholder: no fish body registered yet
	reptilian = { "dragon_wyvern", "amphibian_frog" },
	arachnid = { "rodent_rat" }, -- placeholder: needs dmobs wasp / Meshy
	mollusk = { "amphibian_frog" }, -- placeholder
	humanoid = { "ursine_bear" }, -- placeholder: needs dmobs orc/skeleton
	construct = { "ursine_bear", "equine_horse" }, -- placeholder: needs dmobs golem
	celestial = { "avian_owl", "equine_horse" },
	spectral = { "avian_bat", "avian_owl" },
	fungal = { "amphibian_frog", "rodent_rat" },
	crystalline = { "dragon_wyvern", "feline_cat" },
	amorphous = { "amphibian_frog", "rodent_rat" },
	hybrid = { "canine_fox", "feline_cat", "avian_bat" },
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
		pool = G0_POOLS[element_type]
	else
		-- Beyond Genesis the compiled archetype leads: it is the trait that says
		-- what KIND of creature this is, so it selects the candidate bodies.
		pool = ARCHETYPE_BODY_POOLS[pick_archetype(dna)]
	end

	pool = filter_registered(pool or {})
	if #pool == 0 then
		-- Never fall back to a single hardcoded body — that is what collapsed
		-- every Hashimon into a wolf. Use whatever is actually registered.
		pool = hashimon.list_bodies()
	end
	if #pool == 0 then
		return nil
	end

	-- Reserved nibble [8] picks the body within the pool.
	return dna_pick(dna, 8, 1, pool)
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

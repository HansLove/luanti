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

-- ORDEN CONGELADO. El rasgo se elige con dna_pick(dna, 51, 1, ...), así que la
-- POSICIÓN es la identidad: reordenar esta lista le cambiaría la firma a cada
-- Hashimon ya nacido. Renombrar un valor en su sitio es seguro (la firma se
-- deriva en cada lectura y no se guarda en ninguna parte); moverlo no lo es.
--
-- El valor 2 se renombró a diadem para no chocar con el Signo Hashiano Crown:
-- eran espacios de nombres distintos y no rompía nada, pero un Crown con ese
-- rasgo se leía como intencional, y al filtrar logs birth_spirit y signature
-- se confundían.
local SIGNATURE_FEATURES = {
	"none", "diadem", "wings", "horns", "tail", "aura", "gemstone", "appendages",
}

-- Build and size MODULATE the stage scale; they must not dominate it. The
-- previous ranges (0.85..1.18 and 0.75..1.50) multiplied out to 0.64x at the
-- low end, so a delicate+diminutive stage-1 creature ended up roughly a third
-- of its mesh's authored size. These bands keep the trait readable while
-- leaving stage in charge of how big a Hashimon actually is.
local BUILD_SCALE = {
	delicate = 0.92, lean = 0.96, balanced = 1.0, stocky = 1.05,
	muscular = 1.08, bulbous = 1.10, angular = 0.98, round = 1.03,
}

local SIZE_SCALE = {
	diminutive = 0.85, small = 0.93, medium = 1.0, large = 1.10, huge = 1.20, massive = 1.30,
}

-- Element pools, expressed as FAMILY names — never as body ids.
--
-- This is the licence firewall. hashimon_core must not know that a "theropod"
-- happens to be paleotest_velociraptor.b3d (GPL-3.0) or that a "construct" is
-- dmobs golem.b3d (CC BY-SA 3.0). Core states intent; whichever body pack is
-- installed answers it through hashimon.register_body(). Swap or delete a pack
-- and the DNA, species and protocol are untouched — only the silhouette changes.
--
-- A family with no registered body is skipped at selection time, so a world
-- without the optional packs still works with whatever it does have.
local G0_FAMILY_POOLS = {
	fuego = { "canine", "feline", "theropod", "dragon", "megafauna" },
	agua = { "aquatic", "amphibian", "marine_reptile", "crocodilian", "rodent" },
	aire = { "avian", "pterosaur", "feline", "arthropod" },
	tierra = { "ursine", "equine", "ceratopsian", "stegosaur", "chelonian", "livestock" },
	["eléctrico"] = { "rodent", "feline", "canine", "avian", "marsupial" },
	electrico = { "rodent", "feline", "canine", "avian", "marsupial" },
	pixel = { "feline", "rodent", "construct", "avian" },
	onda = { "avian", "aquatic", "amphibian", "pterosaur" },
	astro = { "avian", "pterosaur", "dragon", "equine", "construct" },
	["sueño"] = { "avian", "feline", "amphibian", "marsupial" },
	sueno = { "avian", "feline", "amphibian", "marsupial" },
	magia = { "avian", "feline", "dragon", "humanoid", "flora" },
	metal = { "ursine", "construct", "chelonian", "megafauna", "sauropod" },
	hongo = { "amphibian", "rodent", "flora", "arthropod", "chelonian" },
	mental = { "avian", "feline", "rodent", "humanoid" },
	vegetal = { "flora", "amphibian", "chelonian", "livestock", "sauropod" },
	["espíritu"] = { "avian", "feline", "canine", "humanoid" },
	espiritu = { "avian", "feline", "canine", "humanoid" },
	["vacío"] = { "avian", "dragon", "humanoid", "marine_reptile", "construct" },
	vacio = { "avian", "dragon", "humanoid", "marine_reptile", "construct" },
}

-- Archetype -> candidate families, for births past Genesis.
local ARCHETYPE_FAMILY_POOLS = {
	canine = { "canine" },
	feline = { "feline" },
	ursine = { "ursine", "megafauna" },
	avian = { "avian", "pterosaur" },
	aquatic = { "aquatic", "marine_reptile" },
	reptilian = { "theropod", "crocodilian", "ceratopsian", "stegosaur", "chelonian" },
	arachnid = { "arthropod" },
	mollusk = { "aquatic", "amphibian" },
	humanoid = { "humanoid", "marsupial" },
	construct = { "construct" },
	celestial = { "pterosaur", "dragon", "equine" },
	spectral = { "avian", "humanoid" },
	fungal = { "flora", "amphibian" },
	crystalline = { "dragon", "construct", "ceratopsian" },
	amorphous = { "aquatic", "amphibian" },
	hybrid = { "canine", "feline", "avian", "marsupial" },
}

-- Size tiers keep a stage-1 player off a five-node sauropod. Derived from the
-- body's own hitbox height, so a pack author never declares this by hand.
local function size_tier(body)
	local h = (body and body.hitbox and body.hitbox.height) or 0.7
	if h < 1.0 then return 1 end
	if h < 2.5 then return 2 end
	return 3
end

--- Largest size tier a creature may wear at this stage.
function hashimon.max_size_tier(stage)
	stage = stage or 1
	if stage >= 15 then return 3 end
	if stage >= 6 then return 2 end
	return 1
end

--- Registered bodies belonging to a family, no larger than max_tier.
function hashimon.bodies_in_family(family, max_tier)
	local out = {}
	for id, body in pairs(hashimon._body_registry) do
		if body.family == family and size_tier(body) <= (max_tier or 3) then
			out[#out + 1] = id
		end
	end
	table.sort(out) -- deterministic: pairs() order is not stable across runs
	return out
end

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
	-- V1 usaba el prefijo `genesis_`; V2 usa `g2_<espíritu>_<elemento>`. Ambos
	-- son generación 0. Sólo importa en el camino de reserva (un Genesis V2
	-- resuelve su linaje por espíritu antes de llegar aquí), pero llamarle
	-- generación 1 a un Genesis sería falso y el error saldría en otro lado.
	if creature.speciesKey
		and (creature.speciesKey:match("^genesis_") or creature.speciesKey:match("^g2_"))
	then
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

--- Families from a list that actually have at least one registered body.
--- Deliberately NOT filtered by size tier: which family a creature belongs to
--- must not change as it grows.
local function available_families(families)
	local out = {}
	for _, family in ipairs(families or {}) do
		if #hashimon.bodies_in_family(family, 3) > 0 then
			out[#out + 1] = family
		end
	end
	return out
end

--- Bodies of a whole spirit line, ordered smallest to largest.
---
--- The families of one line are MERGED into a single ladder on purpose. Ten of
--- the 25 families hold exactly one body, so a per-family ladder left them with
--- no evolution at all: an `equine` Hashimon was a horse forever. Merged, Herd
--- climbs pig -> sheep -> reindeer -> cow -> horse across livestock/cervid/
--- equine.
---
--- Crossing families inside a line is NOT the incoherence bug that produced
--- parrotfish -> whale -> frog. What is fixed for life is the SPIRIT, and no
--- line mixes silhouettes that would let a fish end up a theropod.
local function evolution_line(families)
	local ids = {}
	for _, family in ipairs(families) do
		for _, id in ipairs(hashimon.bodies_in_family(family, 3)) do
			ids[#ids + 1] = id
		end
	end
	table.sort(ids, function(a, b)
		local ha = hashimon.get_body(a).hitbox.height
		local hb = hashimon.get_body(b).hitbox.height
		if ha == hb then return a < b end -- stable tiebreak
		return ha < hb
	end)
	return ids
end

--- Families of a Birth Spirit's line that actually have a registered body.
---
--- Returns nil when the whole line AND every kin line are unregistered, so the
--- caller can fall back to whatever the world does have.
---
--- Measured: with only the MIT pack installed, tyrant, bulwark and golem have
--- no body at all (theropod/crocodilian are GPL-3.0; construct/humanoid/
--- chelonian are CC BY-SA). Substituting the kin line keeps those births
--- playable. It does NOT change the published identity — you are still a
--- Tyrant, you just wear another mesh. Identity is protocol; body is render,
--- and that separation is the whole point of the licence firewall.
local function spirit_line_families(spirit_key)
	local spirit = hashimon.spirit_by_key(spirit_key)
	local seen = {}
	while spirit and not seen[spirit.key] do
		seen[spirit.key] = true
		local fams = available_families(spirit.line)
		if #fams > 0 then
			return fams
		end
		spirit = spirit.kin and hashimon.spirit_by_key(spirit.kin) or nil
	end
	return nil
end

--- Pick the body a creature wears right now.
---
--- Two rules keep evolution coherent, and both exist because of a real bug: the
--- first version re-picked from a stage-filtered pool, so the same DNA landed on
--- a different index as the pool grew. A water Hashimon went
--- parrotfish -> whale -> FROG, and a hedgehog turned into a crocodile.
---
---   1. The FAMILY is chosen from DNA + element only. Never from stage. A fish
---      is a fish for life; it can never become a theropod.
---   2. Inside that family, DNA picks the creature's FINAL body once — its
---      destiny. While the creature is too low-stage to carry it, it wears the
---      largest body of the same family that its stage does allow.
---
--- So growth walks up one family's line (minnow -> dolphin -> whale) and lands
--- on the body the DNA chose at birth. Same shape as a Pokemon evolution line,
--- and just as predetermined.
local function pick_body_id(creature, dna, element_type, generation, stage)
	local entry = species_entry(creature)
	if entry and entry.skeleton and hashimon._body_registry[entry.skeleton] then
		return entry.skeleton
	end

	-- A Genesis V2 carries its Birth Spirit in its speciesKey, and the spirit --
	-- not the element, and never the DNA -- owns the line. G0_FAMILY_POOLS only
	-- still serves V1 Genesis rows that were archived rather than rewritten.
	local spirit = hashimon.spirit_of_species(creature and creature.speciesKey)
	local families = spirit and spirit_line_families(spirit) or nil

	if not families then
		if entry and entry.bodyFamily then
			families = { entry.bodyFamily }
		elseif generation <= 0 then
			families = G0_FAMILY_POOLS[element_type]
		else
			families = ARCHETYPE_FAMILY_POOLS[pick_archetype(dna)]
		end
		families = available_families(families)
	end
	if #families == 0 then
		-- No pack covers the intended families; fall back to whatever exists so a
		-- creature is never bodyless.
		local all = {}
		for _, id in ipairs(hashimon.list_bodies()) do
			local fam = hashimon.get_body(id).family
			if fam then all[fam] = true end
		end
		for fam in pairs(all) do families[#families + 1] = fam end
		table.sort(families)
	end
	if #families == 0 then
		return nil
	end

	-- A Genesis V2 walks its whole spirit line. Every other birth still picks a
	-- single family with nibble [8], and that family is fixed for life.
	local line = evolution_line(spirit and families or { dna_pick(dna, 8, 1, families) })
	if #line == 0 then
		return nil
	end

	-- [59]: destiny body within the family. Also fixed for life.
	local destiny = dna_pick(dna, 59, 1, line)
	local max_tier = hashimon.max_size_tier(stage)
	if size_tier(hashimon.get_body(destiny)) <= max_tier then
		return destiny
	end

	-- Too big for now: wear the largest body of this family that is allowed.
	local worn = line[1]
	for _, id in ipairs(line) do
		if size_tier(hashimon.get_body(id)) <= max_tier then
			worn = id
		end
	end
	return worn
end

-- Per-part proportions, as ABSTRACT multipliers. Core never names a bone: it
-- says "this creature has a slightly big head" and the body pack maps that onto
-- whatever its skeleton calls that part. Same firewall as the family pools.
--
-- Six independent traits, one reserved nibble each. Ranges are deliberately
-- narrow: bone scale composes with the animation, so a 1.5x head does not read
-- as "characterful", it reads as broken.
local PART_TRAITS = {
	headScale   = { pos = 53, min = 0.86, span = 0.34 }, -- 0.86 .. 1.20
	neckLength  = { pos = 54, min = 0.88, span = 0.27 }, -- 0.88 .. 1.15
	torsoWidth  = { pos = 55, min = 0.93, span = 0.17 }, -- 0.93 .. 1.10
	torsoLength = { pos = 56, min = 0.93, span = 0.17 }, -- 0.93 .. 1.10
	limbLength  = { pos = 57, min = 0.90, span = 0.22 }, -- 0.90 .. 1.12
	tailScale   = { pos = 58, min = 0.85, span = 0.35 }, -- 0.85 .. 1.20
}

-- The build trait already describes the silhouette; let it bias the parts so
-- "stocky" and "delicate" mean something beyond overall size.
local BUILD_BIAS = {
	delicate = { torsoWidth = -0.05, limbLength = 0.04 },
	lean     = { torsoWidth = -0.03, torsoLength = 0.03, limbLength = 0.03 },
	balanced = {},
	stocky   = { torsoWidth = 0.05, limbLength = -0.03 },
	muscular = { torsoWidth = 0.06, headScale = 0.03, limbLength = 0.02 },
	bulbous  = { torsoWidth = 0.08, torsoLength = -0.02, limbLength = -0.05 },
	angular  = { torsoWidth = -0.02, torsoLength = 0.02, limbLength = 0.02 },
	round    = { torsoWidth = 0.04, torsoLength = -0.03, limbLength = -0.04 },
}

--- Turn trait scalars into a per-axis scale vector for one part.
---
--- EXTENSION POINT. Everything is uniform today, on purpose: a bone's local
--- axes are model-dependent, and scaling a neck along the wrong one makes it
--- fat instead of long. torsoWidth/torsoLength and neckLength/limbLength are
--- already derived separately and carried through — the moment the bone-local
--- axis convention is confirmed in-game for a given skeleton, this is the only
--- function that has to change, and no pack or core caller moves.
local function axes(part, t)
	if part == "head" then
		return { x = t.headScale, y = t.headScale, z = t.headScale }
	elseif part == "neck" then
		local v = t.neckLength
		return { x = v, y = v, z = v }
	elseif part == "torso" then
		-- Average until the axes are known; the two traits stay distinct above.
		local v = (t.torsoWidth + t.torsoLength) * 0.5
		return { x = v, y = v, z = v }
	elseif part == "tail" then
		return { x = t.tailScale, y = t.tailScale, z = t.tailScale }
	end
	local v = t.limbLength
	return { x = v, y = v, z = v }
end

--- Abstract per-part scale vectors for a creature.
--- Nibbles [53]-[58] are reserved space; this is their first use.
function hashimon.derive_proportions(dna, look)
	local build = (look and look.build) or "balanced"
	local bias = BUILD_BIAS[build] or {}
	local t = {}
	for name, spec in pairs(PART_TRAITS) do
		local w = tonumber(dna:sub(spec.pos, spec.pos), 16) or 0
		t[name] = spec.min + (w / 16) * spec.span + (bias[name] or 0)
	end
	return {
		traits = t, -- the six raw values, for callers that want them individually
		head = axes("head", t),
		neck = axes("neck", t),
		torso = axes("torso", t),
		limbs = axes("limbs", t),
		tail = axes("tail", t),
	}
end

--- "^[contrast:<c>:<b>" for bodies that declare a lift, "" otherwise.
local function contrast_mod(body_def)
	local c = body_def and body_def.contrast
	if not c then
		return ""
	end
	return string.format("^[contrast:%d:%d", c[1] or 0, c[2] or 0)
end

local function resolve_attachments(signature, element_type, look, stage)
	local attachments = {}
	if signature == "horns" or signature == "diadem" then
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
	-- ESCALA. En Luanti un nodo mide BS = 10 unidades internas (src/constants.h),
	-- y content_cao.cpp:706 aplica setScale(visual_size) SIN multiplicar por BS.
	-- Por tanto:
	--
	--     altura_en_nodos = unidades_de_malla * visual_size / 10
	--
	-- Los cuerpos .b3d de los packs vienen autorados a 1 unidad = 1 nodo, y por
	-- eso todos usan visual_size_base = 10: 1 * 10 / 10 = 1 nodo. Un asset
	-- propio raramente sale a esa escala (el de Meshy vino a 3.62 unidades para
	-- una cría de 0.6 nodos), así que declarando `mesh_height` la base se deriva
	-- sola y nadie tiene que hacer la cuenta a mano. Calcularla mal no da error:
	-- sólo deja la criatura diez veces demasiado pequeña.
	local base = body_def and body_def.visual_size_base
	if not base and body_def and body_def.mesh_height and body_def.mesh_height > 0 then
		local target = (body_def.hitbox and body_def.hitbox.height) or 1
		base = target * 10 / body_def.mesh_height
	end
	base = base or 10
	local s = base * stage_scale * build * size
	return { x = s, y = s }
end

--- Pick a texture variant across the body's ACTUAL variant count.
---
--- This used to call wolf_texture_index(), which is hardcoded to `(n % 4) + 1`
--- because the wolf ships four skins. Every body inherited that 4, so the cat's
--- 9 variants and the horse's 6 had their tails silently unreachable. It also
--- summed raw DNA bytes instead of reading nibbles like the rest of the
--- compiler. Nibbles [33]-[34] are reserved space and give 256 values to spread.
function hashimon.morph_texture_index(creature, body_def)
	local count = (body_def and body_def.textures and #body_def.textures) or 1
	if count <= 1 then
		return 1
	end
	local w = tonumber((creature.dna or "0"):sub(33, 34), 16) or 0
	local i = math.floor((w / 256) * count) + 1
	if i > count then i = count end
	return i
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
	local stage = hashimon.creature_stage(creature)
	local body_id = pick_body_id(creature, creature.dna, element_type, generation, stage)
	local body_def = body_id and hashimon.get_body(body_id)
	if not body_def then
		return nil
	end

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
		texture_index = hashimon.morph_texture_index(creature, body_def),
		-- Single luminance-preserving recolour. There used to be a second,
		-- element-derived flat colorize applied on top of this one (element_mod),
		-- which is what made every Water Hashimon the same blue regardless of its
		-- DNA. Colour is the individual's axis; the element does not touch it.
		--
		-- The optional contrast lift runs FIRST: [colorizehsl tints the luminance
		-- structure, so a body whose only skins are near-flat needs that structure
		-- pulled apart before tinting or it renders as one solid blob.
		texture_mod = contrast_mod(body_def) .. hashimon.texture_mod_from_ramp(ramp),
		visual_size = hashimon.morph_visual_size(creature, look, body_def),
		proportions = hashimon.derive_proportions(creature.dna, look),
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

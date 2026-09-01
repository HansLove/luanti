-- Morphology spawn queue + roster entry point.

hashimon = hashimon or {}

hashimon._morph_setup_queue = hashimon._morph_setup_queue or {}

function hashimon.enqueue_morph_setup(owner, creature, morph)
	table.insert(hashimon._morph_setup_queue, {
		owner = owner,
		creature = creature,
		morph = morph,
	})
end

function hashimon.dequeue_morph_setup()
	return table.remove(hashimon._morph_setup_queue, 1)
end

--- Spawn a canonical Creatura body from compiled morphology.
function hashimon.spawn_morph_creature(pos, creature, owner)
	if not hashimon.morphology_available or not hashimon.compile_morphology then
		return nil
	end
	local morph = hashimon.compile_morphology(creature)
	if not morph or not morph.body_id then
		return nil
	end
	local entity_name = "hashimon_bodies:" .. morph.body_id
	if not core.registered_entities[entity_name] then
		return nil
	end
	hashimon.enqueue_morph_setup(owner, creature, morph)
	local obj = core.add_entity(pos, entity_name)
	if not obj then
		hashimon.dequeue_morph_setup()
		return nil
	end
	return obj
end

-- ---------------------------------------------------------------------------
-- /hbody — invocar un cuerpo concreto para revisarlo.
--
-- No fuerza el cuerpo por la vía corta. BUSCA un ADN que realmente produzca ese
-- cuerpo pasando por compile_morphology, así que lo que aparece es una criatura
-- que un jugador podría tener de verdad: su color, sus proporciones y su
-- textura salen del mismo camino que en producción.
--
-- Forzar `morph.body_id` a posteriori habría sido más simple y habría mentido:
-- mostraría una combinación que el compilador quizá nunca genera.
-- ---------------------------------------------------------------------------

local function random_dna()
	local hex = {}
	for i = 1, 64 do hex[i] = string.format("%x", math.random(0, 15)) end
	return table.concat(hex)
end

--- Especies Genesis V2 cuyo linaje puede contener este cuerpo.
local function candidate_species(body_id)
	local body = hashimon.get_body(body_id)
	if not body then return {} end
	local out = {}
	for _, spirit in ipairs(hashimon.SPIRITS or {}) do
		for _, fam in ipairs(spirit.line) do
			if fam == body.family then
				for _, element in ipairs(hashimon.ELEMENTS or {}) do
					out[#out + 1] = hashimon.genesis_species_key(spirit.key, element)
				end
				break
			end
		end
	end
	return out
end

--- Busca un ADN que compile a `body_id` en ese stage. nil si no lo encuentra.
local function find_dna_for(body_id, stage, tries)
	local species = candidate_species(body_id)
	if #species == 0 then return nil, nil, "ningún signo tiene la familia de ese cuerpo" end
	for _ = 1, tries or 4000 do
		local sk = species[math.random(#species)]
		local dna = random_dna()
		local m = hashimon.compile_morphology({ dna = dna, speciesKey = sk, stage = stage })
		if m and m.body_id == body_id then
			return dna, sk
		end
	end
	-- El fallo casi siempre es de tier, no de mala suerte: un cuerpo grande no
	-- existe en un stage bajo. Decirlo con el número exacto ahorra el "¿por qué
	-- no aparece?".
	local body = hashimon.get_body(body_id)
	local h = (body and body.hitbox and body.hitbox.height) or 0
	local need = (h >= 2.5 and 15) or (h >= 1.0 and 6) or 1
	if stage < need then
		return nil, nil, string.format(
			"%s mide %.2f nodos y no se desbloquea hasta el stage %d. Prueba: /hbody %s %d",
			body_id, h, need, body_id, need)
	end
	-- El otro motivo, y el menos evidente: la criatura CAMINA su línea según el
	-- stage, así que un cuerpo tardío no es alcanzable en un stage temprano
	-- aunque su tier sí lo permita. Se calcula el stage mínimo real.
	local line, pos = nil, nil
	for _, sp in ipairs(hashimon.SPIRITS or {}) do
		local l = {}
		for _, f in ipairs(sp.line) do
			for _, bid in ipairs(hashimon.bodies_in_family(f, 3)) do l[#l + 1] = bid end
		end
		table.sort(l, function(a, b)
			local ha, hb = hashimon.get_body(a).hitbox.height, hashimon.get_body(b).hitbox.height
			if ha == hb then return a < b end
			return ha < hb
		end)
		for i, bid in ipairs(l) do
			if bid == body_id then line, pos = l, i end
		end
	end
	if line and pos and pos > 1 then
		local need_walk = math.ceil(1 + 19 * (pos - 1.5) / (#line - 1))
		if stage < need_walk then
			return nil, nil, string.format(
				"%s es el cuerpo %d de %d en su línea; no se alcanza hasta el stage %d. Prueba: /hbody %s %d",
				body_id, pos, #line, need_walk, body_id, need_walk)
		end
	end
	return nil, nil, "no salió tras 4000 intentos; revisa el log del servidor"
end

core.register_chatcommand("hbody", {
	params = "<body_id> [stage] | list [familia]",
	description = "Invoca un cuerpo concreto con un ADN real que lo produzca",
	privs = { server = true },
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then return false, "jugador no encontrado" end

		local args = {}
		for w in param:gmatch("%S+") do args[#args + 1] = w end
		local body_id = args[1]

		if not body_id or body_id == "list" then
			local filter = args[2]
			local out = {}
			for _, id in ipairs(hashimon.list_bodies()) do
				local b = hashimon.get_body(id)
				if not filter or b.family == filter then
					out[#out + 1] = string.format("%s (%s, %.2f)", id, b.family, b.hitbox and b.hitbox.height or 0)
				end
			end
			return true, #out .. " cuerpos:\n" .. table.concat(out, "\n")
		end

		if not hashimon.get_body(body_id) then
			return false, "cuerpo desconocido: " .. body_id .. "  (prueba /hbody list)"
		end

		local stage = tonumber(args[2]) or 1
		local dna, species_key, err = find_dna_for(body_id, stage)
		if not dna then
			return false, err
		end

		local creature = {
			dna = dna,
			speciesKey = species_key,
			stage = stage,
			name = body_id,
			generation = 0,
		}
		local pos = player:get_pos()
		local look = player:get_look_dir()
		local obj = hashimon.spawn_morph_creature(
			{ x = pos.x + look.x * 3, y = pos.y + 1, z = pos.z + look.z * 3 },
			creature, name)
		if not obj then
			return false, "spawn_morph_creature devolvió nil — revisa el log del servidor"
		end

		local m = hashimon.compile_morphology(creature)
		local p = m.proportions and m.proportions.traits or {}
		return true, string.format(
			"%s  ·  %s  ·  stage %d  ·  ADN %s…\n" ..
			"tamaño %.2f  ·  textura %d  ·  cabeza %.2f cuello %.2f torso %.2f extrem %.2f",
			body_id, species_key, stage, dna:sub(1, 8),
			m.visual_size and m.visual_size.x or 0, m.texture_index or 1,
			p.headScale or 1, p.neckLength or 1, p.torsoWidth or 1, p.limbLength or 1)
	end,
})

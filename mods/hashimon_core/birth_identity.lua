-- Birth Identity (Capa A) — el destino compartido.
--
-- Puerto Lua de api/src/core/birth-identity.ts. DEBE producir resultados
-- idénticos: scripts/validate_birth_identity.mjs corre los dos intérpretes
-- reales (node y luajit) sobre las 17,897 fechas de 1970-2018 y compara. Un
-- espejo que sólo se "revisa a ojo" valida únicamente a sí mismo.
--
--     Fecha    -> destino compartido  (este archivo)
--     Servidor -> individuo singular  (DNA, dna_compiler.lua, morphology.lua)
--
-- Sin SHA-256 en toda la capa: sumar dígitos y mirar dos tablas. Un jugador
-- puede auditar su identidad con papel.

hashimon = hashimon or {}

hashimon.BIRTH_IDENTITY_VERSION = 2

-- Ortografía EXACTA de dna_compiler.lua TYPES (con acento). El alias ascii sólo
-- construye claves.
hashimon.ELEMENT_ASCII = {
	fuego = "fuego",
	agua = "agua",
	aire = "aire",
	tierra = "tierra",
	["eléctrico"] = "electrico",
}

-- Orden canónico: debe coincidir con Object.keys(ELEMENT_ASCII) en TS, que en
-- JS conserva el orden de inserción para claves de texto.
hashimon.ELEMENTS = { "fuego", "agua", "aire", "tierra", "eléctrico" }

hashimon.ELEMENT_PREFIX = {
	fuego = "Ember", agua = "Tide", aire = "Gust",
	tierra = "Root", ["eléctrico"] = "Volt",
}

-- Número de Vida -> Genesis. Tabla canónica, nunca selección aleatoria.
-- El 5 es de Aire: con el 5 en Fuego, Fuego se llevaba el 33.3% de los
-- nacimientos medidos contra el 13.7% de Aire.
hashimon.ELEMENT_BY_LIFE = {
	[1] = "fuego", [3] = "fuego",
	[2] = "aire", [5] = "aire", [7] = "aire",
	[4] = "tierra", [8] = "tierra",
	[6] = "agua", [9] = "agua",
	[11] = "eléctrico", [22] = "eléctrico", [33] = "eléctrico",
}

-- Sólo lore y color de UI. Nada del compilador lo lee.
hashimon.UNDERTONE_BY_LIFE = { [11] = "aire", [22] = "tierra", [33] = "agua" }

-- Los doce SIGNOS HASHIANOS. Son arquetipos, no animales: el nombre describe el
-- rasgo y la familia corporal es sólo cómo se manifiesta. `hearth` es canino
-- porque un cánido encarna vínculo y manada — pero si mañana el pack cambia la
-- silueta, el signo sigue siendo Hearth. Nombrarlos "Lobo" habría atado la
-- identidad al asset, que es justo lo que el firewall de licencias evita.
--
-- Los doce linajes cubren las 25 familias registradas EXACTAMENTE: sin sobras y
-- sin repeticiones.
--
-- `line` son NOMBRES DE FAMILIA, jamás ids de asset — el mismo firewall de
-- licencias que G0_FAMILY_POOLS. El core declara "este espíritu es acuático";
-- el pack instalado responde con la malla que tenga.
--
-- `kin` es el linaje sustituto cuando NINGUNA familia del linaje propio tiene
-- cuerpo registrado (mundo sin los packs opcionales GPL/CC BY-SA). Medido:
-- tyrant, bulwark y golem quedan huérfanos con sólo el pack MIT. La sustitución
-- NO cambia la identidad publicada — sigues siendo Tyrant, sólo vistes otra
-- malla. Identidad = protocolo; cuerpo = render.
-- NOMBRES PROVISIONALES: depth, edge y road. El resto está cerrado.
--
-- Nombran su arquetipo de forma más literal que los otros nueve, y `depth` casi
-- repite su propia familia. Cambiar uno NO es cosmético: la clave
-- g2_<signo>_<elemento> entra en el preimagen del ADN, así que renombrar con
-- jugadores ya nacidos obliga a renacerlos. Ahora es gratis; después no.
hashimon.SPIRITS = {
	{ key = "hearth", name = "Hearth", name_es = "Hogar",
	  archetype = "vínculo, lealtad, hogar, comunidad",
	  line = { "canine" }, kin = nil },
	{ key = "mirror", name = "Mirror", name_es = "Espejo",
	  archetype = "intuición, reserva, percepción",
	  line = { "feline" }, kin = nil },
	{ key = "guardian", name = "Guardian", name_es = "Guardián",
	  archetype = "protección, fuerza, responsabilidad",
	  line = { "ursine", "megafauna" }, kin = nil },
	{ key = "beacon", name = "Beacon", name_es = "Faro",
	  archetype = "visión, dirección, descubrimiento",
	  line = { "avian", "pterosaur" }, kin = nil },
	-- PROVISIONAL
	{ key = "depth", name = "Depth", name_es = "Abismo",
	  archetype = "mundo interior, adaptación, paciencia",
	  line = { "aquatic", "marine_reptile" }, kin = nil },
	{ key = "crown", name = "Crown", name_es = "Corona",
	  archetype = "presencia, ambición, autoridad",
	  line = { "dragon" }, kin = nil },
	-- PROVISIONAL
	{ key = "edge", name = "Edge", name_es = "Filo",
	  archetype = "decisión, instinto, intensidad",
	  line = { "theropod", "crocodilian" }, kin = "crown" },
	{ key = "bastion", name = "Bastion", name_es = "Bastión",
	  archetype = "resistencia, estabilidad, memoria",
	  line = { "chelonian", "ceratopsian", "stegosaur", "sauropod" }, kin = "guardian" },
	-- PROVISIONAL
	{ key = "road", name = "Road", name_es = "Camino",
	  archetype = "viaje, constancia, libertad",
	  -- Podado 2026-08-31: livestock sale a Natural. Es la línea que producía la
	  -- oveja gigante de diez estrellas.
	  line = { "equine", "cervid" }, kin = nil },
	{ key = "key", name = "Key", name_es = "Llave",
	  archetype = "ingenio, oportunidad, supervivencia",
	  -- Podado 2026-08-31: rodent y marsupial salen a Natural. `serpentine` es
	  -- familia propia — ningún mod instalado tiene topología serpentina.
	  -- kin = edge: si un mundo no tiene el pack propio, `serpentine` se queda sin
	  -- cuerpos y Key necesita a quién parecerse. Los cocodrilianos de Edge son lo
	  -- más cercano a una silueta serpentina en todo el catálogo.
	  -- (Antes decía "wyrm", un nombre animal anterior al renombrado arquetípico
	  -- que ya no existe: el fallback habría buscado un signo inexistente.)
	  line = { "serpentine" }, kin = "edge" },
	{ key = "forge", name = "Forge", name_es = "Fragua",
	  archetype = "creación, voluntad, transformación",
	  -- `ape` es familia propia: un simio no es ni constructo ni humanoide, y
	  -- ningún mod instalado tiene uno. Va primera porque es el linaje curado.
	  line = { "ape", "construct", "humanoid" }, kin = "hearth" },
	{ key = "bloom", name = "Bloom", name_es = "Brote",
	  archetype = "cambio, renovación, crecimiento",
	  -- Podado 2026-08-31: amphibian sale a Natural; la rana le ganaba el stage 1
	  -- a la mantis cría por 5 centésimas de nodo.
	  line = { "arthropod", "flora" }, kin = nil },
}

local SPIRIT_BY_KEY = {}
for _, s in ipairs(hashimon.SPIRITS) do SPIRIT_BY_KEY[s.key] = s end

function hashimon.spirit_by_key(key)
	return SPIRIT_BY_KEY[key]
end

--- Suma de dígitos reducida a 1..9, conservando 11/22/33 como maestros.
--- El maestro se comprueba EN CADA PASO, no sólo en el primer total.
function hashimon.life_number(dob)
	local n = 0
	for i = 1, #dob do
		local b = dob:byte(i)
		if b >= 48 and b <= 57 then n = n + (b - 48) end
	end
	while n > 9 do
		if n == 11 or n == 22 or n == 33 then return n end
		local next_n = 0
		local s = tostring(n)
		for i = 1, #s do next_n = next_n + (s:byte(i) - 48) end
		n = next_n
	end
	return n
end

--- ISO YYYY-MM-DD estricto, calendario real. Devuelve nil en vez de lanzar.
function hashimon.parse_dob(dob)
	if type(dob) ~= "string" then return nil end
	local y, m, d = dob:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if not y then return nil end
	y, m, d = tonumber(y), tonumber(m), tonumber(d)
	if m < 1 or m > 12 or d < 1 then return nil end
	local dim = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	local last = dim[m]
	if m == 2 and (y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)) then last = 29 end
	if d > last then return nil end
	return y, m, d
end

--- Ventana solar -> espíritu. El día 21 abre la ventana del mes en curso.
function hashimon.spirit_of(dob)
	local _, m, d = hashimon.parse_dob(dob)
	if not m then return nil end
	local i = (d >= 21) and (m - 1) or (m - 2)
	i = ((i % 12) + 12) % 12
	return hashimon.SPIRITS[i + 1].key
end

function hashimon.genesis_species_key(spirit, element)
	return "g2_" .. spirit .. "_" .. hashimon.ELEMENT_ASCII[element]
end

function hashimon.genesis_template_id(spirit, element)
	return "template_g2_" .. spirit .. "_" .. hashimon.ELEMENT_ASCII[element]
end

function hashimon.genesis_species_name(spirit, element)
	return hashimon.ELEMENT_PREFIX[element] .. " " .. SPIRIT_BY_KEY[spirit].name
end

--- La identidad completa, o nil si la fecha no es válida.
function hashimon.birth_identity(dob)
	local spirit = hashimon.spirit_of(dob)
	if not spirit then return nil end
	local life = hashimon.life_number(dob)
	local element = hashimon.ELEMENT_BY_LIFE[life]
	if not element then return nil end
	return {
		lifeNumber = life,
		element = element,
		undertone = hashimon.UNDERTONE_BY_LIFE[life],
		spirit = spirit,
		spiritName = SPIRIT_BY_KEY[spirit].name,
		speciesKey = hashimon.genesis_species_key(spirit, element),
		templateId = hashimon.genesis_template_id(spirit, element),
		version = hashimon.BIRTH_IDENTITY_VERSION,
	}
end

--- Espíritu de una speciesKey Genesis V2 ("g2_depth_agua" -> "depth").
--- Devuelve nil para cualquier otra cosa: un Hashimon salvaje no tiene espíritu.
function hashimon.spirit_of_species(species_key)
	if type(species_key) ~= "string" then return nil end
	local rest = species_key:match("^g2_(.+)$")
	if not rest then return nil end
	for _, s in ipairs(hashimon.SPIRITS) do
		if rest:sub(1, #s.key + 1) == s.key .. "_" then return s.key end
	end
	return nil
end

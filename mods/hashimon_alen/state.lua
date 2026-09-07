-- La ficha de Alen: la AUTORIDAD sobre si existe, dónde está y cuánta vida tiene.
--
-- La entidad de Luanti es sólo una proyección de esta ficha, nunca al revés. Es lo
-- que hace que "sólo puede haber uno en todo el mapa" sea una invariante y no una
-- esperanza: las entidades se duplican al reactivarse un mapblock con
-- static_save = true, y se pierden con static_save = false. Los dos fallos
-- desaparecen cuando la entidad no es la fuente de verdad.
--
-- Hoy persiste en mod_storage. Cuando exista la fila en Postgres, sólo cambian
-- load() y save(); nada más en el mod la toca.

hashimon_alen = hashimon_alen or {}

local storage = core.get_mod_storage()
local KEY = "alen_state"

hashimon_alen.MAX_HP = 400

local DEFAULT = {
	-- Físico
	alive = false,      -- ¿Alen existe en el mundo ahora mismo?
	pos = nil,          -- dónde está, lo esté observando alguien o no
	yaw = 0,
	hp = hashimon_alen.MAX_HP,
	plan = nil,         -- plan de verbos vigente (lo llena el canal de órdenes)
	born_at = nil,
	last_saved = 0,

	-- Los OCHO campos psicológicos. Ni uno más: todo lo demás (sueño, confianza,
	-- humor, saciedad) se deriva en psyche.lua. Guardar lo derivable es cómo un
	-- Alen acaba con fatiga 90 y sueño 5 sin que nadie lo note.
	energy = 100,
	anger = 0,
	fatigue = 0,
	boredom = 0,
	destruction_desire = 0,
	awake = true,
	slept_at = nil,
	last_state_update_at = 0,  -- el ancla de la puesta al día offline

	-- Identidad y conocimiento
	seed = nil,          -- semilla de personalidad; los rasgos se derivan de ella
	schema_v = 2,
	known_players = {},  -- SÓLO knowledge.lua escribe aquí
	last_attacker = nil, -- copia global, únicamente para redactar el WHY
	last_damage_at = nil,
	-- Si estaba en el suelo al retirarse. No es derivable: es un hecho sobre el
	-- mundo. Sin él, un Alen que se durmió en tierra reaparece flotando.
	grounded = false,
	current_goal = nil,
	current_target = nil,
	goal_since = nil,
	last_safe_position = nil,
}

local state

local function deep_copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = type(v) == "table" and deep_copy(v) or v
	end
	return out
end

function hashimon_alen.load_state()
	if state then
		return state
	end
	local raw = storage:get_string(KEY)
	if raw and raw ~= "" then
		local ok, parsed = pcall(core.parse_json, raw)
		if ok and type(parsed) == "table" then
			state = parsed
			-- Rellena claves nuevas sin pisar lo guardado, para que añadir un campo
			-- no invalide la partida en curso.
			for k, v in pairs(DEFAULT) do
				if state[k] == nil then
					state[k] = type(v) == "table" and deep_copy(v) or v
				end
			end
			return state
		end
		core.log("warning", "[alen] ficha corrupta en mod_storage, arrancando de cero")
	end
	state = deep_copy(DEFAULT)
	return state
end

function hashimon_alen.save_state()
	local s = hashimon_alen.load_state()
	s.last_saved = os.time()
	storage:set_string(KEY, core.write_json(s))
end

--- Borra a Alen por completo: ficha, memoria y todo. Es una herramienta de
--- desarrollo — al experimentar hace falta poder volver a cero sin borrar el mundo.
function hashimon_alen.reset_state()
	state = deep_copy(DEFAULT)
	storage:set_string(KEY, "")
	return state
end

function hashimon_alen.get_state()
	return hashimon_alen.load_state()
end

--- Da de alta a Alen en el mapa. Falla si ya está vivo — este es el candado del
--- singleton, y vive aquí y no en el comando para que ninguna otra ruta lo salte.
function hashimon_alen.birth(pos)
	local s = hashimon_alen.load_state()
	if s.alive then
		return false, "ya_existe"
	end
	local now = os.time()
	s.alive = true
	s.pos = { x = pos.x, y = pos.y, z = pos.z }
	s.hp = hashimon_alen.MAX_HP
	s.plan = nil
	s.born_at = now

	-- Un Alen nuevo es una personalidad nueva. La semilla se guarda una sola vez
	-- y los seis rasgos se derivan de ella con sha256, igual que el ADN de un
	-- Hashimon: el mismo Alen es siempre el mismo carácter.
	s.seed = hashimon_alen.new_seed()
	s.energy = hashimon_alen.MAX_ENERGY
	s.anger, s.fatigue, s.boredom, s.destruction_desire = 0, 0, 0, 0
	s.awake = true
	s.slept_at = now
	s.last_state_update_at = now
	s.last_attacker, s.last_damage_at = nil, nil
	hashimon_alen.save_state()
	return true
end

--- Lo retira del mapa por completo (muerte o borrado de admin). Distinto de
--- despawn: despawn sólo quita la entidad y conserva la ficha.
function hashimon_alen.death(reason)
	local s = hashimon_alen.load_state()
	s.alive = false
	s.plan = nil
	hashimon_alen.save_state()
	core.log("action", "[alen] Alen Gregory ha caído: " .. tostring(reason or "?"))
end

--- Copia la posición/vida/yaw de la entidad viva a la ficha. Se llama antes de
--- retirar la entidad y periódicamente, para que un cierre bruto pierda segundos
--- y no la partida.
function hashimon_alen.sync_from_entity(self)
	local s = hashimon_alen.load_state()
	local pos = self.object:get_pos()
	if pos then
		s.pos = { x = pos.x, y = pos.y, z = pos.z }
	end
	s.yaw = self.object:get_yaw() or 0
	s.hp = self.hp or s.hp
	if hashimon_alen.is_grounded then
		s.grounded = hashimon_alen.is_grounded(self)
	end
end

-- La memoria por jugador vive ahora en knowledge.lua, que es el ÚNICO fichero
-- que la escribe. Aquí sólo queda la ficha; lo que Alen sabe tiene su propia
-- puerta, y esa separación es lo que hace auditable la regla epistémica.

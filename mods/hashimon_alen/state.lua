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
	alive = false,      -- ¿Alen existe en el mundo ahora mismo?
	pos = nil,          -- dónde está, lo esté observando alguien o no
	yaw = 0,
	hp = hashimon_alen.MAX_HP,
	mood = "acecho",    -- etiqueta de intención; la capa del modelo escribirá aquí
	plan = nil,         -- plan de verbos vigente (lo llenará el canal de órdenes)
	memory = {},        -- qué jugadores conoce y cómo acabó la última vez
	born_at = nil,
	last_saved = 0,
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
	s.alive = true
	s.pos = { x = pos.x, y = pos.y, z = pos.z }
	s.hp = hashimon_alen.MAX_HP
	s.mood = "acecho"
	s.plan = nil
	s.born_at = os.time()
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
	s.mood = self.mood or s.mood
end

--- Lo que Alen recuerda de un jugador. La capa del modelo lee esto y escribe el
--- resultado; en Lua sólo se cuentan los encuentros.
function hashimon_alen.remember(player_name, outcome)
	local s = hashimon_alen.load_state()
	local m = s.memory[player_name]
	if not m then
		m = { met = 0, wins = 0, losses = 0, last = nil }
		s.memory[player_name] = m
	end
	m.met = m.met + 1
	m.last = outcome
	if outcome == "alen_won" then
		m.wins = m.wins + 1
	elseif outcome == "alen_lost" then
		m.losses = m.losses + 1
	end
end

function hashimon_alen.knows(player_name)
	local s = hashimon_alen.load_state()
	return s.memory[player_name]
end

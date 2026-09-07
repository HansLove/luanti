-- Lo que Alen SABE, que no es lo que el servidor sabe.
--
-- Este fichero es EL ÚNICO SITIO DEL MOD QUE ESCRIBE CONOCIMIENTO. No es una
-- convención de estilo: es la forma de la regla. "Acuérdate de no consultar la
-- base de datos para saber de qué pueblo es Bob" se rompe en la tercera semana;
-- "sólo knowledge.lua escribe known_players" se audita con un grep y sigue
-- siendo cierto dentro de un año.
--
-- Todo lo demás en el mod puede LEER (knows, relation_label). Nadie más escribe.

hashimon_alen = hashimon_alen or {}

hashimon_alen.KNOWLEDGE_SCHEMA_V = 2

-- --------------------------------------------------------------------------
-- La ficha de una relación: cinco escalares, no un enum.
--
-- Un enum exclusivo obliga a elegir entre "me divierte" y "lo odio", y Alen
-- puede sentir las dos cosas a la vez — eso es precisamente lo que lo hace
-- interesante. Las etiquetas legibles se derivan de los escalares, abajo.
-- --------------------------------------------------------------------------

local function blank_relation(now)
	return {
		first_seen = now,
		last_seen = now,
		times_seen = 0,
		sentiment = 0,   -- -100 … +100
		grudge = 0,      --    0 … 100
		respect = 0,
		fear = 0,
		interest = 0,
		grudge_marked = false, -- ¿superó alguna vez el umbral de cicatriz?
		beaten = 0,      -- veces que Alen lo derrotó
		beaten_by = 0,
		last_event = nil,
		last_event_at = nil,
	}
end

--- Lectura. Devuelve nil si no lo conoce — y "no lo conoce" es un estado
--- perfectamente válido que el resto del sistema debe respetar: un desconocido
--- no es un enemigo.
function hashimon_alen.knows(name)
	local s = hashimon_alen.get_state()
	return s.known_players and s.known_players[name] or nil
end

--- Etiqueta derivada, nunca almacenada. Un jugador puede ser RESPECTED con
--- sentimiento negativo: Alen respeta a quien le hizo daño de verdad.
function hashimon_alen.relation_label(name)
	local r = hashimon_alen.knows(name)
	if not r then return "UNKNOWN" end
	if r.grudge >= 60 then return "HOSTILE" end
	if r.respect >= 60 and r.interest >= 40 then return "RESPECTED" end
	if r.interest >= 70 and r.grudge < 30 then return "AMUSED" end
	if r.sentiment >= 40 then return "LIKED" end
	if r.grudge >= 25 then return "DISLIKED" end
	if r.interest >= 40 then return "CURIOUS" end
	if r.times_seen <= 2 then return "SUSPICIOUS" end
	return "INDIFFERENT"
end

-- --------------------------------------------------------------------------
-- EL ESCRITOR ÚNICO
--
-- `obs` es siempre algo que Alen PERCIBIÓ. Nada entra aquí que no haya pasado
-- delante de él. No hay ni una consulta a Towny, ni a la tabla de jugadores, ni
-- a nada que él no pudiera ver.
-- --------------------------------------------------------------------------

local function touch(name)
	local s = hashimon_alen.get_state()
	s.known_players = s.known_players or {}
	local now = os.time()
	local r = s.known_players[name]
	if not r then
		r = blank_relation(now)
		s.known_players[name] = r
	end
	r.last_seen = now
	return r, s
end

local function bump(r, field, delta, lo, hi)
	r[field] = hashimon_alen.clamp((r[field] or 0) + delta, lo, hi)
end

--- Registra una observación. Devuelve la relación resultante.
function hashimon_alen.alen_learn(obs)
	if type(obs) ~= "table" or not obs.kind then
		return nil
	end
	local who = obs.who
	if not who then
		return nil
	end

	local r, s = touch(who)
	local now = os.time()
	r.last_event = obs.kind
	r.last_event_at = now

	if obs.kind == "attacked_me" then
		local dmg = obs.damage or 1
		-- La subida de ira que pediste, con sus dos multiplicadores compuestos:
		-- despertarlo a golpes repetidos lo lleva a WRATHFUL de un tirón.
		-- Base 30, no 18: desde la perspectiva de Alen, que alguien inferior lo
		-- toque es un ultraje en sí mismo, casi con independencia de lo que duela.
		local gain = (30 + dmg * 1.2) * hashimon_alen.trait_mult("wrath", 0.35)
		if obs.asleep then gain = gain * 2.5 end
		if obs.combo then gain = gain * 1.4 end

		s.anger = hashimon_alen.clamp((s.anger or 0) + gain, 0, 100)
		bump(r, "grudge", gain * 0.75, 0, 100)
		bump(r, "sentiment", -(8 + dmg * 0.4), -100, 100)
		bump(r, "interest", 6, 0, 100)
		-- Hacerle daño de verdad se gana respeto aunque le duela.
		if dmg >= 15 then bump(r, "respect", dmg * 0.35, 0, 100) end
		if dmg >= 40 then bump(r, "fear", dmg * 0.15, 0, 100) end

		if r.grudge >= hashimon_alen.GRUDGE_FLOOR_AT then
			r.grudge_marked = true -- la cicatriz: ya no vuelve a ser un desconocido
		end
		s.last_attacker = who
		s.last_damage_at = now
		s.boredom = 0

	elseif obs.kind == "seen" then
		r.times_seen = (r.times_seen or 0) + 1
		bump(r, "interest", r.times_seen <= 3 and 8 or 2, 0, 100)
		s.boredom = math.max(0, (s.boredom or 0) - 15)

	elseif obs.kind == "escaped" then
		-- Sobrevivir a Alen es la forma más rápida de que se fije en ti.
		bump(r, "respect", 12, 0, 100)
		bump(r, "interest", 15, 0, 100)

	elseif obs.kind == "i_defeated" then
		r.beaten = (r.beaten or 0) + 1
		bump(r, "grudge", -25, 0, 100)
		bump(r, "fear", 10, 0, 100)
		bump(r, "interest", -10, 0, 100)

	elseif obs.kind == "defeated_me" then
		r.beaten_by = (r.beaten_by or 0) + 1
		bump(r, "grudge", 45, 0, 100)
		bump(r, "respect", 25, 0, 100)
		r.grudge_marked = true

	elseif obs.kind == "peaceful_approach" then
		bump(r, "sentiment", 6, -100, 100)
		bump(r, "interest", 8, 0, 100)

	elseif obs.kind == "appraised" then
		-- Lo que el modelo juzgó de una conversación. Entra por aquí y no por una
		-- vía propia: si el conocimiento tuviera dos escritores, la regla
		-- epistémica dejaría de poder auditarse con un grep.
		local ego = obs.ego or 0
		if ego < 0 then
			-- El ego herido es ira, y ES el mecanismo que pediste: una frase que no
			-- suena agresiva puede subir la métrica y acabar en un ataque.
			s.anger = hashimon_alen.clamp((s.anger or 0) + (-ego) * 0.55, 0, 100)
			bump(r, "grudge", (-ego) * 0.35, 0, 100)
			bump(r, "sentiment", ego * 0.4, -100, 100)
		else
			bump(r, "sentiment", ego * 0.35, -100, 100)
			s.anger = math.max(0, (s.anger or 0) - ego * 0.2)
		end
		bump(r, "interest", obs.interest or 0, 0, 100)
		bump(r, "respect", obs.respect or 0, 0, 100)
		if r.grudge >= hashimon_alen.GRUDGE_FLOOR_AT then
			r.grudge_marked = true
		end

	elseif obs.kind == "left" then
		bump(r, "interest", -4, 0, 100)
	end

	hashimon_alen.prune_knowledge()
	return r
end

-- --------------------------------------------------------------------------
-- Decaimiento del rencor: misma mecánica que la ira, otra escala de tiempo.
-- Eso resuelve solo lo que pedías — la ira baja y el rencor se queda.
-- --------------------------------------------------------------------------

function hashimon_alen.decay_relationships(dt)
	local s = hashimon_alen.get_state()
	if not s.known_players then return end
	local hl = hashimon_alen.GRUDGE_HALF_LIFE * hashimon_alen.trait_mult("patience", 0.4)
	for _, r in pairs(s.known_players) do
		r.grudge = hashimon_alen.decay_with_floor(r.grudge or 0, dt, hl,
			hashimon_alen.GRUDGE_FLOOR, r.grudge_marked)
		-- El interés se enfría más rápido que el rencor: el aburrimiento es más
		-- barato de conseguir que el perdón.
		r.interest = hashimon_alen.decay_half_life(r.interest or 0, dt, 7200)
		-- sentiment, respect y fear NO decaen. Lo que aprendió de alguien no se
		-- desaprende con el tiempo; sólo se corrige con otra interacción.
	end
end

-- --------------------------------------------------------------------------
-- Techo con expulsión.
--
-- El criterio no es sólo antigüedad: EL RENCOR COMPRA TIEMPO. Una hora de
-- retención por punto de rencor, así que quien lo despertó a golpes sobrevive
-- en su memoria a decenas de desconocidos. Expulsar por pura antigüedad
-- borraría exactamente lo que hace que valga la pena recordar.
-- --------------------------------------------------------------------------

function hashimon_alen.prune_knowledge()
	local s = hashimon_alen.get_state()
	if not s.known_players then return 0 end

	local list, n = {}, 0
	for name, r in pairs(s.known_players) do
		n = n + 1
		list[n] = { name = name, score = (r.last_seen or 0) + (r.grudge or 0) * 3600 }
	end
	local over = n - hashimon_alen.MAX_KNOWN_PLAYERS
	if over <= 0 then return 0 end

	table.sort(list, function(a, b) return a.score < b.score end)
	for i = 1, over do
		s.known_players[list[i].name] = nil
	end
	core.log("action", "[alen] memoria podada: " .. over .. " conocidos olvidados")
	return over
end

--- Preparar una relación a mano para poder PROBAR. Vive aquí y no en commands.lua
--- por la misma razón que todo lo demás: si el conocimiento tuviera dos escritores,
--- la regla epistémica dejaría de auditarse con un grep.
hashimon_alen.DEBUG_RELATIONS = {
	nuevo    = { sentiment = 0,   grudge = 0,  respect = 0,  fear = 0,  interest = 0 },
	odia     = { sentiment = -85, grudge = 80, respect = 25, fear = 0,  interest = 60 },
	aprecia  = { sentiment = 70,  grudge = 0,  respect = 45, fear = 0,  interest = 70 },
	respeta  = { sentiment = 10,  grudge = 15, respect = 85, fear = 10, interest = 75 },
	teme     = { sentiment = -30, grudge = 20, respect = 70, fear = 80, interest = 40 },
}

function hashimon_alen.debug_set_relation(name, preset)
	local p = hashimon_alen.DEBUG_RELATIONS[preset]
	if not p then return false end
	local s = hashimon_alen.get_state()
	s.known_players = s.known_players or {}
	if preset == "nuevo" then
		s.known_players[name] = nil
		return true
	end
	local now = os.time()
	local r = blank_relation(now)
	for k2, v in pairs(p) do r[k2] = v end
	r.times_seen = 5
	r.grudge_marked = r.grudge >= hashimon_alen.GRUDGE_FLOOR_AT
	r.last_event = (preset == "odia") and "attacked_me" or "peaceful_approach"
	s.known_players[name] = r
	return true
end

-- --------------------------------------------------------------------------
-- Migración desde el `memory` viejo (met/wins/losses/last). Una sola pasada,
-- guiada por schema_v; la fusión de claves nuevas que ya hacía load_state()
-- cubre todo lo demás.
-- --------------------------------------------------------------------------

function hashimon_alen.migrate_knowledge()
	local s = hashimon_alen.get_state()
	if (s.schema_v or 1) >= hashimon_alen.KNOWLEDGE_SCHEMA_V then
		return 0
	end
	local now = os.time()
	local moved = 0
	s.known_players = s.known_players or {}
	for name, m in pairs(s.memory or {}) do
		if not s.known_players[name] then
			local r = blank_relation(now)
			r.times_seen = m.met or 0
			r.beaten = m.wins or 0
			r.beaten_by = m.losses or 0
			r.last_event = m.last
			-- Quien lo derrotó arranca con rencor: la memoria vieja no guardaba
			-- sentimiento, pero sí guardaba quién ganó.
			if (m.losses or 0) > 0 then
				r.grudge = math.min(100, 40 * m.losses)
				r.grudge_marked = r.grudge >= hashimon_alen.GRUDGE_FLOOR_AT
				r.respect = math.min(100, 20 * m.losses)
			end
			s.known_players[name] = r
			moved = moved + 1
		end
	end
	s.memory = nil
	s.schema_v = hashimon_alen.KNOWLEDGE_SCHEMA_V
	if moved > 0 then
		core.log("action", "[alen] memoria migrada: " .. moved .. " relaciones reformadas")
	end
	return moved
end
